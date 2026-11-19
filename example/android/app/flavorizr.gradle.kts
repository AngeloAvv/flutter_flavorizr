import com.android.build.api.dsl.ApplicationExtension

val android = project.extensions.getByType(ApplicationExtension::class.java)

android.apply {
    flavorDimensions += "flavor-type"

    productFlavors {
        create("apple") {
            dimension = "flavor-type"
            applicationId = "com.example.apple"
            resValue(type = "string", name = "app_name", value = "Apple App")
        }
        create("banana") {
            dimension = "flavor-type"
            applicationId = "com.example.banana"
            resValue(type = "string", name = "app_name", value = "Banana App")
        }
    }

    buildFeatures.resValues = true
}