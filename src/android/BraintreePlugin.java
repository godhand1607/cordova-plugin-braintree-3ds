package org.apache.cordova.braintree;

import android.util.Log;

import androidx.annotation.NonNull;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

import com.braintreepayments.api.BraintreeClient;
import com.braintreepayments.api.ClientTokenCallback;
import com.braintreepayments.api.ClientTokenProvider;
import com.braintreepayments.api.DataCollector;
import com.braintreepayments.api.GooglePayCapabilities;
import com.braintreepayments.api.GooglePayCardNonce;
import com.braintreepayments.api.GooglePayClient;
import com.braintreepayments.api.GooglePayListener;
import com.braintreepayments.api.GooglePayRequest;
import com.braintreepayments.api.PaymentMethodNonce;
import com.braintreepayments.api.ReadyForGooglePayRequest;
import com.braintreepayments.api.UserCanceledException;

import com.google.android.gms.wallet.TransactionInfo;
import com.google.android.gms.wallet.WalletConstants;


public final class BraintreePlugin extends CordovaPlugin implements GooglePayListener, ClientTokenProvider {

    private static final String TAG = "BraintreePlugin";

    private CallbackContext _callbackContext = null;
    private String deviceDataCollector = null;
    private String temporaryToken = null;

    private BraintreeClient braintreeClient;
    private GooglePayClient googlePayClient;
    private DataCollector dataCollector;


    /**
     * Sets the context of the Command. This can then be used to do things like
     * get file paths associated with the Activity.
     *
     * @param cordova The context of the main Activity.
     * @param webView The CordovaWebView Cordova is running in.
     */
    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        Log.i(TAG, "Initializing...");

        cordova.getActivity().runOnUiThread(() -> {
            Log.i(TAG, "Initialize onUiThread start");

            braintreeClient = new BraintreeClient(cordova.getActivity(), this);

            googlePayClient = new GooglePayClient(cordova.getActivity(), braintreeClient);
            googlePayClient.setListener(this);

            dataCollector = new DataCollector(braintreeClient);

            Log.i(TAG, "Initialize onUiThread end");
        });
    }


    @Override
    public boolean execute(String action, final JSONArray args, final CallbackContext callbackContext) throws JSONException {

        if (action == null) {
            Log.e(TAG, "execute ==> exiting for bad action");
            return false;
        }

        Log.w(TAG, "execute ==> " + action + " === " + args);

        _callbackContext = callbackContext;

        try {
            if (action.equals("initialize")) {
                this.initializeBT(args);
            } else if (action.equals("canMakePayments")) {
                this.canMakePayments(args);
            } else if (action.equals("launchGooglePay")) {
                this.launchGooglePay(args);
            } else {
                return false;
            }
        } catch (Exception exception) {
            callbackContext.error("BraintreePlugin uncaught exception: " + exception.getMessage());
        }

        return true;
    }

    private void initializeBT(final JSONArray args) throws Exception {

        if (args.length() != 1) {
            _callbackContext.error("A token is required.");
            return;
        }

        String token = args.getString(0);

        if (token == null || token.equals("")) {
            _callbackContext.error("A token is required.");
            return;
        }

        temporaryToken = token;

        _callbackContext.success();
    }

    private void canMakePayments(final JSONArray args) throws JSONException {
        braintreeClient.getConfiguration((configuration, error) -> {
            if (configuration == null) {
                Log.e(TAG, "canMakePayments: braintree null config -> " + error.getMessage() + "\n" + error.getStackTrace());

                _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, false));
                return;
            }

            if (GooglePayCapabilities.isGooglePayEnabled(cordova.getActivity(), configuration)) {

                ReadyForGooglePayRequest readyForGooglePayRequest = new ReadyForGooglePayRequest();
                readyForGooglePayRequest.setExistingPaymentMethodRequired(true);

                googlePayClient.isReadyToPay(cordova.getActivity(), readyForGooglePayRequest, (isReadyToPay, e) -> {
                    if (e != null) {
                        Log.e(TAG, "canMakePayments: googlePayClient.isReadyToPay -> " + e.getMessage() + "\n" + e.getStackTrace());

                        // showDialog("Google Payments are not available. The following issues could be the cause:\n\n" +
                        //         "No user is logged in to the device.\n\n" +
                        //         "Google Play Services is missing or out of date.");
                        _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, false));
                        return;
                    }

                    _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, isReadyToPay));
                });
            } else {
                Log.e(TAG, "canMakePayments: GooglePayCapabilities.isGooglePayEnabled -> false");

                // showDialog("Google Payments are not available. The following issues could be the cause:\n\n" +
                //         "Google Payments are not enabled for the current merchant.\n\n" +
                //         "Google Play Services is missing or out of date.");

                _callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, false));
            }
        });
    }


    private void collectDeviceData() {
        dataCollector.collectDeviceData(cordova.getActivity(), (deviceData, error) -> {
            deviceDataCollector = deviceData;
        });
    }

    private boolean hasElement(JSONArray requiredContactFields, String key) throws JSONException {
        for (int i = 0 ; i < requiredContactFields.length(); i++) {
            boolean isMatch = requiredContactFields.getString(i) == key;
            if (isMatch) {
                return true;
            }
        }
        return false;
    }

    private void launchGooglePay(final JSONArray args) throws JSONException {
        String amount = args.getString(0);
        String currency = args.getString(1);
        String environment = args.getString(2);
        JSONArray requiredContactFields = args.getJSONArray(3);
        JSONArray cardTypes = args.getJSONArray(4);

        GooglePayRequest googlePayRequest = new GooglePayRequest();
        googlePayRequest.setEnvironment(environment);
        googlePayRequest.setTransactionInfo(TransactionInfo.newBuilder()
            .setCurrencyCode(currency)
            .setTotalPrice(amount)
            .setTotalPriceStatus(WalletConstants.TOTAL_PRICE_STATUS_FINAL)
            .build());
        googlePayRequest.setEmailRequired(this.hasElement(requiredContactFields, "emailAddress"));
        googlePayRequest.setBillingAddressRequired(true);
        googlePayRequest.setBillingAddressFormat(WalletConstants.BILLING_ADDRESS_FORMAT_FULL);
        googlePayRequest.setPhoneNumberRequired(this.hasElement(requiredContactFields, "phoneNumber"));
//        googlePayRequest.setGoogleMerchantId();
//        googlePayRequest.setAllowedPaymentMethod("CARD");
        googlePayRequest.setAllowedCardNetworks("CARD", cardTypes);
        Log.i(TAG, googlePayRequest.toJson());

        this.collectDeviceData();

        googlePayClient.requestPayment(cordova.getActivity(), googlePayRequest);
    }


    @Override
    public void onGooglePaySuccess(@NonNull PaymentMethodNonce paymentMethodNonce) {
        Log.i(TAG, "onGooglePaySuccess: paymentMethodNonce = " + paymentMethodNonce.getString());

        Map<String, Object> resultMap = new HashMap<String, Object>();
        resultMap.put("userCancelled", false);
        resultMap.put("nonce", paymentMethodNonce.getString());
        resultMap.put("deviceData", deviceDataCollector);

        if (paymentMethodNonce instanceof GooglePayCardNonce) {
            GooglePayCardNonce googlePayCardNonce = (GooglePayCardNonce) paymentMethodNonce;
            resultMap.put("emailAddress", googlePayCardNonce.getEmail());
            resultMap.put("name",  googlePayCardNonce.getBillingAddress().getRecipientName());
            resultMap.put("phoneNumber", googlePayCardNonce.getBillingAddress().getPhoneNumber());
        }

        _callbackContext.success(new JSONObject(resultMap));
        _callbackContext = null;
    }


    @Override
    public void onGooglePayFailure(@NonNull Exception error) {
        if (error instanceof UserCanceledException) {
            Log.i(TAG, "onUserCancellation: " + error.getMessage() + "\n" + error.getStackTrace());

            Map<String, Object> resultMap = new HashMap<String, Object>();
            resultMap.put("userCancelled", true);
            if (_callbackContext != null) {
                _callbackContext.success(new JSONObject(resultMap));
            }
        } else {
            Log.e(TAG, "onGooglePayFailure: " + error.getMessage() + "\n" + error.getStackTrace());

            if (_callbackContext != null) {
                _callbackContext.error("onGooglePayFailure: " + error.getMessage());
            }
        }

        _callbackContext = null;
    }

    @Override
    public void getClientToken(@NonNull ClientTokenCallback callback) {
        if (temporaryToken != null) {
            callback.onSuccess(temporaryToken);
        } else {
            callback.onFailure(new Exception("Null token"));
        }
    }
}
