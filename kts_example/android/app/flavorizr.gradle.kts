android {
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
}