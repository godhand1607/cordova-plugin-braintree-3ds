//
//  BraintreePlugin.m
//
//  Copyright (c) 2016 Justin Unterreiner. All rights reserved.
//

#import "BraintreePlugin.h"
#import <objc/runtime.h>
#import <Braintree/BTAPIClient.h>
#import <Braintree/BTPaymentMethodNonce.h>
#import <Braintree/BTCardNonce.h>
#import <Braintree/BraintreeApplePay.h>
#import <Braintree/BraintreeDataCollector.h>

@interface BraintreePlugin() <PKPaymentAuthorizationViewControllerDelegate>

@property (nonatomic, strong) BTAPIClient * braintreeClient;
@property (nonatomic, strong) BTDataCollector * dataCollector;
@property (nonatomic, strong) NSString * _Nonnull deviceDataCollector;
@property NSString * token;

@end

@implementation BraintreePlugin

NSString * dropInUIcallbackId;
bool applePaySuccess;
NSString * applePayMerchantID;
NSString * currencyCode;
NSString * countryCode;

#pragma mark - Cordova commands

- (void)initialize:(CDVInvokedUrlCommand *)command {

    // Ensure we have the correct number of arguments.
    if ([command.arguments count] != 1) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"A token is required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    // Obtain the arguments.
    self.token = [command.arguments objectAtIndex:0];

    if (!self.token) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"A token is required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    self.braintreeClient = [[BTAPIClient alloc] initWithAuthorization:self.token];

    if (!self.braintreeClient) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The Braintree client failed to initialize."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    self.dataCollector = [[BTDataCollector alloc] initWithAPIClient:self.braintreeClient];
    [self.dataCollector collectDeviceData:^(NSString * _Nonnull deviceDataCollector) {
        // Save deviceData
        self.deviceDataCollector = deviceDataCollector;
    }];

//    NSString *bundle_id = [NSBundle mainBundle].bundleIdentifier;
//    bundle_id = [bundle_id stringByAppendingString:@".payments"];
//
//    [BTAppContextSwitcher setReturnURLScheme:bundle_id];

    CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
}

- (void)setupApplePay:(CDVInvokedUrlCommand *)command {

    // Ensure the client has been initialized.
    if (!self.braintreeClient) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The Braintree client must first be initialized via BraintreePlugin.initialize(token)"];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    if ([command.arguments count] != 3) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Merchant id, Currency code and Country code are required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    if ((PKPaymentAuthorizationViewController.canMakePayments) && ([PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:@[PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkAmex, PKPaymentNetworkDiscover]])) {
        applePayMerchantID = [command.arguments objectAtIndex:0];
        currencyCode = [command.arguments objectAtIndex:1];
        countryCode = [command.arguments objectAtIndex:2];

        // applePayInited = YES;

        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
    } else {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"ApplePay cannot be used."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
    }
}

- (void)presentDropInPaymentUI:(CDVInvokedUrlCommand *)command {

    // Ensure the client has been initialized.
    if (!self.braintreeClient) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The Braintree client must first be initialized via BraintreePlugin.initialize(token)"];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    // Ensure we have the correct number of arguments.
    if ([command.arguments count] < 1) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"amount required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    // Obtain the arguments.
    NSString* amount = (NSString *)[command.arguments objectAtIndex:0];
    if ([amount isKindOfClass:[NSNumber class]]) {
        amount = [(NSNumber *)amount stringValue];
    }
    if (!amount) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"amount is required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    NSString* primaryDescription = [command.arguments objectAtIndex:1];

    // Save off the Cordova callback ID so it can be used in the completion handlers.
    dropInUIcallbackId = command.callbackId;

    [self presentApplePayWithDescription:primaryDescription andAmount:amount];
}

- (void)presentApplePayWithDescription:(NSString*)description andAmount:(NSString*)amount {

    BTApplePayClient *applePayClient = [[BTApplePayClient alloc] initWithAPIClient:self.braintreeClient];
    [applePayClient paymentRequest:^(PKPaymentRequest * _Nullable paymentRequest, NSError * _Nullable error) {

        if (error != nil) {
            NSLog(@"Error: %@",[error localizedDescription]);
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];

            [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
            dropInUIcallbackId = nil;

            return;
        }

        paymentRequest.paymentSummaryItems = @[
            [PKPaymentSummaryItem summaryItemWithLabel:description
                                                amount:[NSDecimalNumber decimalNumberWithString: amount]]
        ];
        paymentRequest.supportedNetworks = @[
            PKPaymentNetworkVisa,
            PKPaymentNetworkMasterCard,
            PKPaymentNetworkAmex,
            PKPaymentNetworkDiscover
        ];
        paymentRequest.merchantCapabilities = PKMerchantCapability3DS;
//        paymentRequest.requiredBillingContactFields = [PKContactFieldEmailAddress];

        paymentRequest.currencyCode = currencyCode;
        paymentRequest.countryCode = countryCode;

        paymentRequest.merchantIdentifier = applePayMerchantID;

        PKPaymentAuthorizationViewController *viewController = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest:paymentRequest];
        viewController.delegate = self;

        applePaySuccess = NO;

        /* display ApplePay ont the rootViewController */
        UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];

        [rootViewController presentViewController:viewController animated:YES completion:nil];
    }];
}

#pragma mark - PKPaymentAuthorizationViewControllerDelegate
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didAuthorizePayment:(PKPayment *)payment handler:(void (^)(PKPaymentAuthorizationResult * _Nonnull))completion {
    applePaySuccess = YES;

    BTApplePayClient *applePayClient = [[BTApplePayClient alloc] initWithAPIClient:self.braintreeClient];

    [applePayClient tokenizeApplePayPayment:payment completion:^(BTApplePayCardNonce *tokenizedApplePayPayment, NSError *error) {
        if (tokenizedApplePayPayment) {
            // On success, send nonce to your server for processing.
            NSDictionary *dictionary = [self getPaymentUINonceResult:tokenizedApplePayPayment];

            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                          messageAsDictionary:dictionary];

            [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
            dropInUIcallbackId = nil;

            // Then indicate success or failure via the completion callback, e.g.
            completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusSuccess errors:nil]);
        } else {
            // Tokenization failed. Check `error` for the cause of the failure.
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Apple Pay tokenization failed"];

            [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
            dropInUIcallbackId = nil;

            // Indicate failure via the completion callback:
            completion([[PKPaymentAuthorizationResult alloc] initWithStatus:PKPaymentAuthorizationStatusFailure errors:nil]);
        }
    }];

}

- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller {
    UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];

    [rootViewController dismissViewControllerAnimated:YES completion:nil];

    /* if not success, fire cancel event */
    if (!applePaySuccess) {
        NSDictionary *dictionary = @{ @"userCancelled": @YES };

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK  messageAsDictionary:dictionary];

        [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
        dropInUIcallbackId = nil;
    }
}


#pragma mark - Helpers
/**
 * Helper used to return a dictionary of values from the given payment method nonce.
 * Handles several different types of nonces (eg for cards, Apple Pay, PayPal, etc).
 */
- (NSDictionary*)getPaymentUINonceResult:(BTPaymentMethodNonce *)paymentMethodNonce {

    BTCardNonce *cardNonce;
    BTApplePayCardNonce *applePayCardNonce;

    if ([paymentMethodNonce isKindOfClass:[BTCardNonce class]]) {
        cardNonce = (BTCardNonce*)paymentMethodNonce;
    }

    if ([paymentMethodNonce isKindOfClass:[BTApplePayCardNonce class]]) {
        applePayCardNonce = (BTApplePayCardNonce*)paymentMethodNonce;
    }

    NSDictionary *dictionary = @{
        @"userCancelled": @NO,

        // Standard Fields
        @"nonce": paymentMethodNonce.nonce,
        @"type": paymentMethodNonce.type,
        // @"localizedDescription": paymentMethodNonce.localizedDescription,

        // BTCardNonce Fields
        @"card": !cardNonce
            ? [NSNull null]
            : @{
                @"lastTwo": cardNonce.lastTwo,
                @"network": [self formatCardNetwork:cardNonce.cardNetwork]
            },
        // BTApplePayCardNonce
        @"applePayCard": !applePayCardNonce
            ? [NSNull null]
            : @{},

        // BTThreeDSecureCardNonce Fields
        @"deviceData": self.deviceDataCollector,
    };

    return dictionary;
}

/**
 * Helper used to provide a string value for the given BTCardNetwork enumeration value.
 */
- (NSString*)formatCardNetwork:(BTCardNetwork)cardNetwork {
    NSString *result = nil;

    // TODO: This method should probably return the same values as the Android plugin for consistency.

    switch (cardNetwork) {
        case BTCardNetworkUnknown:
            result = @"BTCardNetworkUnknown";
            break;
        case BTCardNetworkAMEX:
            result = @"BTCardNetworkAMEX";
            break;
        case BTCardNetworkDinersClub:
            result = @"BTCardNetworkDinersClub";
            break;
        case BTCardNetworkDiscover:
            result = @"BTCardNetworkDiscover";
            break;
        case BTCardNetworkMasterCard:
            result = @"BTCardNetworkMasterCard";
            break;
        case BTCardNetworkVisa:
            result = @"BTCardNetworkVisa";
            break;
        case BTCardNetworkJCB:
            result = @"BTCardNetworkJCB";
            break;
        case BTCardNetworkLaser:
            result = @"BTCardNetworkLaser";
            break;
        case BTCardNetworkMaestro:
            result = @"BTCardNetworkMaestro";
            break;
        case BTCardNetworkUnionPay:
            result = @"BTCardNetworkUnionPay";
            break;
        case BTCardNetworkSolo:
            result = @"BTCardNetworkSolo";
            break;
        case BTCardNetworkSwitch:
            result = @"BTCardNetworkSwitch";
            break;
        case BTCardNetworkUKMaestro:
            result = @"BTCardNetworkUKMaestro";
            break;
        default:
            result = nil;
    }

    return result;
}

@end

