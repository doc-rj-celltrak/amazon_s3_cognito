package com.famproperties.amazon_s3_cognito

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import android.content.Intent
import com.amazonaws.mobile.config.AWSConfiguration
import com.amazonaws.mobileconnectors.s3.transferutility.TransferService
import com.amazonaws.mobileconnectors.s3.transferutility.TransferState
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry.Registrar
import org.jetbrains.annotations.NotNull
import java.io.File
import java.io.IOException
import java.io.InterruptedIOException
import java.io.UnsupportedEncodingException
import java.net.SocketTimeoutException


class AmazonS3CognitoPlugin: FlutterPlugin, MethodCallHandler {
    private var awsHelper: AwsHelper? = null

    private lateinit var channel : MethodChannel
    private lateinit var context: Context

    companion object {
        // read config from awsconfiguration.json in android/app/src/<env>/res/raw/,
        // where <env> is one of dev, qa, uat, or prod.
        private lateinit var awsConfig: AWSConfiguration

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "amazon_s3_cognito")
            val context = registrar.context()

            channel.setMethodCallHandler(AmazonS3CognitoPlugin())
            init(context)
        }

        @JvmStatic
        fun init(context: Context) {
            awsConfig = AWSConfiguration(context)
            context.startService(Intent(context, TransferService::class.java))
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "amazon_s3_cognito")
        context = flutterPluginBinding.applicationContext

        channel.setMethodCallHandler(this)
        init(context)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        val fileName = call.argument<String>("imageName")
        val authToken = call.argument<String>("authToken")

        when (call.method) {
            "uploadImage" -> {
                val file = File(filePath!!)
                if (!file.exists()) {
                    result.error(S3Error.fileNotFound.toString(), "$filePath not found", emptyList<String>())
                    return;
                }

                try {
                    awsHelper = AwsHelper(context, awsConfig,
                            authToken!!, fileName!!, object : AwsHelper.OnUploadCompleteListener {
                        override fun onFailed(exception: Exception) {

                            print("\n❌ upload failed ${exception.rootCause}")
                            try {
                                val rootCause = exception.rootCause
                                if (rootCause is SocketTimeoutException || rootCause is InterruptedIOException) {
                                    result.error(S3Error.requestTimedOut.toString(), exception.message, emptyList<String>())
                                } else if (rootCause is IOException || // Includes: UnknownHostException
                                        exception.message == TransferState.WAITING_FOR_NETWORK.toString()) { // AwsHelper treats this as a failure
                                    result.error(S3Error.requestOffline.toString(), exception.message, emptyList<String>())
                                } else {
                                    result.error(S3Error.unknown.toString(), exception.message, emptyList<String>())
                                }
                            } catch (e: Exception) {
                            }
                        }

                        override fun onUploadComplete(@NotNull imageUrl: String) {
                            print("\n✅ upload complete: $imageUrl")
                            result.success(imageUrl)
                        }
                    })
                    awsHelper!!.uploadImage(file)
                } catch (e: UnsupportedEncodingException) {
                    e.printStackTrace()
                }
            }
            "downloadImage" -> {
                val file = File(filePath!!)
                try {
                    awsHelper = AwsHelper(context, awsConfig,
                            authToken!!, fileName!!, object : AwsHelper.OnUploadCompleteListener {
                        override fun onFailed(exception: Exception) {
                            print("\n❌ download failed")
                            try {
                                result.error("s3.downloadImage", exception.message!!, emptyList<String>())
                            } catch (e: Exception) {
                            }
                        }

                        override fun onUploadComplete(@NotNull imageUrl: String) {
                            print("\n✅ download complete: $imageUrl")
                            result.success(imageUrl)
                        }
                    })
                    awsHelper!!.downloadImage(file)
                } catch (e: UnsupportedEncodingException) {
                    e.printStackTrace()
                }
            }
            "deleteImage" -> {
                try {
                    awsHelper = AwsHelper(context, awsConfig,
                            authToken!!, fileName!!, object : AwsHelper.OnUploadCompleteListener {
                        override fun onFailed(exception: Exception) {
                            print("\n❌ delete failed")
                            try {
                                result.error("s3.deleteImage", exception.message!!, emptyList<String>())
                            } catch (e: Exception) {
                            }
                        }

                        override fun onUploadComplete(@NotNull imageUrl: String) {
                            print("\n✅ delete complete: $imageUrl")
                            try {
                                result.success(imageUrl)
                            } catch (e: Exception) {
                            }
                        }
                    })
                    awsHelper!!.deleteImage()
                } catch (e: UnsupportedEncodingException) {
                    e.printStackTrace()
                }
            }
            else -> result.notImplemented()
        }
    }
}

enum class S3Error {
    // Timed out. Could be offline, server could be stalled, etc. Should retry
    requestTimedOut,

    // Temporarily offline, obviously should retry
    requestOffline,

    // The file is gone, this is a permanent error, no retries
    fileNotFound,

    // Lots of potential issues, hopefully transient, so we'll retry
    unknown
}

val Exception.rootCause : Throwable
    get() {
        var previousCause: Throwable = this
        var nextCause = this.cause
        while(nextCause != null) {
            previousCause = nextCause
            nextCause = nextCause.cause
        }
        return previousCause
    }
