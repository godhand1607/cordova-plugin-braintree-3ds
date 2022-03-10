//
//  BraintreePlugin.h
//
//  Copyright (c) 2016 Justin Unterreiner. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>

@interface BraintreePlugin : CDVPlugin
- (void)initialize:(CDVInvokedUrlCommand *)command;
- (void)canMakePayments:(CDVInvokedUrlCommand *)command;
- (void)setupApplePay:(CDVInvokedUrlCommand *)command;
- (void)presentDropInPaymentUI:(CDVInvokedUrlCommand *)command;
- (void)verifyCard:(CDVInvokedUrlCommand *)command;
@end
