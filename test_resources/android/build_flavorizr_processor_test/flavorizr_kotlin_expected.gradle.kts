import com.android.build.api.dsl.ApplicationExtension

val android = project.extensions.getByType(ApplicationExtension::class.java)

android.apply {
    flavorDimensions += "flavor-type"

    productFlavors {
        create("apple") {
            dimension = "flavor-type"
            applicationId = "com.example.apple"
            versionNameSuffix = "-green-prod"
            signingConfig = flavorSigning.green
            versionCode = 1000
            minSdkVersion = 23
            isDefault = true
            resourceConfigurations = listOf("en", "it")
            extras = mapOf("tier" to "gold", "level" to 3)
            manifestPlaceholders["appAuthRedirectScheme"] = "com.example.apple"
            manifestPlaceholders["retries"] = 3
            manifestPlaceholders["label"] = "raw"
            resValue(type = "string", name = "app_name", value = "Apple App")
            resValue(type = "string", name = "variable_one", value = "previous variable one")
            resValue(type = "string", name = "common", value = "test common")
            buildConfigField(type = "String", name = "field_one", value = "\"previous field one\"")
        }
        create("banana") {
            dimension = "flavor-type"
            applicationId = "com.example.banana"
            resValue(type = "string", name = "app_name", value = "Banana\\' App")
            resValue(type = "string", name = "variable_one", value = "test variable\\' one")
            resValue(type = "string", name = "common", value = "test common")
            resValue(type = "string", name = "variable_two", value = "test variable two")
            buildConfigField(type = "String", name = "field_one", value = "\"test field one\"")
            buildConfigField(type = "char", name = "field_two", value = "\'y\'")
            buildConfigField(type = "double", name = "field_three", value = "20.0")
        }
    }

    buildFeatures.resValues = true
    buildFeatures.buildConfig = true
}