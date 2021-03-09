package com.famproperties.amazon_s3_cognito

import java.io.File
import java.io.UnsupportedEncodingException
import org.jetbrains.annotations.NotNull
import android.content.Context

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry.Registrar

import com.amazonaws.mobile.config.AWSConfiguration

class AmazonS3CognitoPlugin private constructor(private val context: Context) : MethodCallHandler {
    // read config from awsconfiguration.json in android/app/src/<env>/res/raw/,
    // where <env> is one of dev, qa, uat, or prod.
    private val awsConfig = AWSConfiguration(context)
    private var awsHelper: AwsHelper? = null

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "amazon_s3_cognito")
            val instance = AmazonS3CognitoPlugin(registrar.context())
            channel.setMethodCallHandler(instance)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        val fileName = call.argument<String>("imageName")
        val authToken = call.argument<String>("authToken")

        when (call.method) {
            "uploadImage" -> {
                val file = File(filePath!!)
                try {
                    awsHelper = AwsHelper(context, awsConfig,
                            authToken!!, fileName!!, object : AwsHelper.OnUploadCompleteListener {
                        override fun onFailed(exception: Exception) {
                            print("\n❌ upload failed")
                            try {
                                result.error("s3.uploadImage", exception.message!!, emptyList<String>())
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
