'use strict';

var exec = require('cordova/exec');

/**
 * The Cordova plugin ID for this plugin.
 */
var PLUGIN_ID = 'BraintreePlugin';

/**
 * The plugin which will be exported and exposed in the global scope.
 */
var BraintreePlugin = {};

/**
 * Used to initialize the Braintree client.
 *
 * The client must be initialized before other methods can be used.
 *
 * @param {string} token - The client token or tokenization key to use with the Braintree client.
 * @param [function] successCallback - The success callback for this asynchronous function.
 * @param [function] failureCallback - The failure callback for this asynchronous function; receives an error string.
 */
BraintreePlugin.initialize = function initialize(token, successCallback, failureCallback) {

  if (!token || typeof (token) !== 'string') {
    failureCallback('A non-null, non-empty string must be provided for the token parameter.');
    return;
  }

  exec(successCallback, failureCallback, PLUGIN_ID, 'initialize', [token]);
};


BraintreePlugin.canMakePayments = function canMakePayments(successCallback, failureCallback) {
  exec(successCallback, failureCallback, PLUGIN_ID, 'canMakePayments', []);
};


/**
 * Used to configure Apple Pay on iOS.
 *
 * @param {object} options - The options used to configure Apple Pay.
 * @param [function] successCallback - The success callback for this asynchronous function.
 * @param [function] failureCallback - The failure callback for this asynchronous function; receives an error string.
 */
BraintreePlugin.setupApplePay = function setupApplePay(options, successCallback, failureCallback) {
  if (!options) {
    options = {};
  }

  if (typeof (options.merchantId) !== 'string') {
    failureCallback('Apple Pay Merchant ID must be provided');
  }
  if (typeof (options.currency) !== 'string') {
    failureCallback('Apple Pay currency must be provided');
  }
  if (typeof (options.country) !== 'string') {
    failureCallback('Apple Pay country must be provided');
  }
  if (!Array.isArray(options.cardTypes)) {
    failureCallback('Apple Pay supported card types must be provided');
  }

  var pluginOptions = [
    options.merchantId,
    options.currency,
    options.country,
    options.cardTypes
  ];

  exec(successCallback, failureCallback, PLUGIN_ID, 'setupApplePay', pluginOptions);
};

/**
 * Shows Braintree's drop-in payment UI.
 *
 * @param {object} options - The options used to control the drop-in payment UI.
 * @param [function] successCallback - The success callback for this asynchronous function; receives a result object.
 * @param [function] failureCallback - The failure callback for this asynchronous function; receives an error string.
 */
BraintreePlugin.presentDropInPaymentUI = function showDropInUI(options, successCallback, failureCallback) {

  if (!options) {
    options = {};
  }

  if (typeof (options.amount) === 'undefined') {
    options.amount = '0.00';
  }
  if (!isNaN(options.amount * 1)) {
    options.amount = (options.amount * 1).toFixed(2);
  }
  if (typeof (options.requiredShippingContactFields) === 'undefined') {
    options.requiredShippingContactFields = [];
  }

  var pluginOptions = [
    options.amount,
    options.primaryDescription,
    options.requiredShippingContactFields
  ];

  exec(successCallback, failureCallback, PLUGIN_ID, 'presentDropInPaymentUI', pluginOptions);
};

BraintreePlugin.verifyCard = function showDropInUI(options, successCallback, failureCallback) {

    var pluginOptions = [
      options.amount,
      options.nonce,
      options.email,
      options.billingAddress.givenName,
      options.billingAddress.surname,
      options.billingAddress.phoneNumber,
      options.billingAddress.countryCodeAlpha2,
    ];

    exec(successCallback, failureCallback, PLUGIN_ID, 'verifyCard', pluginOptions);
};


BraintreePlugin.paypalProcess = function paypalProcess(amount, currency, env, successCallback, failureCallback) {
  exec(successCallback, failureCallback, PLUGIN_ID, 'paypalProcess', [amount, currency, env]);
};

BraintreePlugin.paypalProcessVaulted = function paypalProcessVaulted(env, successCallback, failureCallback) {
  exec(successCallback, failureCallback, PLUGIN_ID, 'paypalProcessVaulted', [env]);
};


module.exports = BraintreePlugin;
