//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "OWSProvisioningMessage.h"
#import "OWSProvisioningCipher.h"
#import "OWSProvisioningProtos.pb.h"
#import <25519/Curve25519.h>
#import <AxolotlKit/NSData+keyVersionByte.h>
#import <HKDFKit/HKDFKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSProvisioningMessage ()

@property (nonatomic, readonly) NSData *myPublicKey;
@property (nonatomic, readonly) NSData *myPrivateKey;
@property (nonatomic, readonly) NSString *accountIdentifier;
@property (nonatomic, readonly) NSData *theirPublicKey;
@property (nonatomic, readonly) NSData *profileKey;
@property (nonatomic, readonly) NSString *provisioningCode;

@end

@implementation OWSProvisioningMessage

- (instancetype)initWithMyPublicKey:(NSData *)myPublicKey
                       myPrivateKey:(NSData *)myPrivateKey
                     theirPublicKey:(NSData *)theirPublicKey
                  accountIdentifier:(NSString *)accountIdentifier
                         profileKey:(NSData *)profileKey
                   provisioningCode:(NSString *)provisioningCode
{
    self = [super init];
    if (!self) {
        return self;
    }

    _myPublicKey = myPublicKey;
    _myPrivateKey = myPrivateKey;
    _theirPublicKey = theirPublicKey;
    _accountIdentifier = accountIdentifier;
    _profileKey = profileKey;
    _provisioningCode = provisioningCode;

    return self;
}

- (nullable NSData *)buildEncryptedMessageBody
{
    OWSProvisioningProtosProvisionMessageBuilder *messageBuilder = [OWSProvisioningProtosProvisionMessageBuilder new];
    [messageBuilder setIdentityKeyPublic:self.myPublicKey];
    [messageBuilder setIdentityKeyPrivate:self.myPrivateKey];
    [messageBuilder setNumber:self.accountIdentifier];
    [messageBuilder setProvisioningCode:self.provisioningCode];
    [messageBuilder setUserAgent:@"OWI"];
    [messageBuilder setProfileKey:self.profileKey];

    NSData *plainTextProvisionMessage = [[messageBuilder build] data];

    OWSProvisioningCipher *cipher = [[OWSProvisioningCipher alloc] initWithTheirPublicKey:self.theirPublicKey];
    NSData *_Nullable encryptedProvisionMessage = [cipher encrypt:plainTextProvisionMessage];
    if (encryptedProvisionMessage == nil) {
        DDLogError(@"Failed to encrypt provision message");
        return nil;
    }

    OWSProvisioningProtosProvisionEnvelopeBuilder *envelopeBuilder = [OWSProvisioningProtosProvisionEnvelopeBuilder new];
    // Note that this is a one-time-use *cipher* public key, not our Signal *identity* public key
    [envelopeBuilder setPublicKey:[cipher.ourPublicKey prependKeyType]];
    [envelopeBuilder setBody:encryptedProvisionMessage];

    return [[envelopeBuilder build] data];
}

@end

NS_ASSUME_NONNULL_END
