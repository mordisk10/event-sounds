plugins {
    id("java")
    id("org.jetbrains.intellij") version "1.17.4"
    id("org.jetbrains.kotlin.jvm") version "1.9.24"
}

group = providers.gradleProperty("pluginGroup").get()
version = providers.gradleProperty("pluginVersion").get()

repositories {
    mavenCentral()
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
}

intellij {
    version.set(providers.gradleProperty("platformVersion").get())
    updateSinceUntilBuild.set(false)
}

tasks {
    buildSearchableOptions {
        enabled = false
    }

    patchPluginXml {
        version.set("${project.version}")
        sinceBuild.set(providers.gradleProperty("pluginSinceBuild").get())
    }

    compileKotlin {
        kotlinOptions.jvmTarget = "17"
    }

    compileTestKotlin {
        kotlinOptions.jvmTarget = "17"
    }

    test {
        useJUnit()
        testLogging {
            events("passed", "skipped", "failed")
            showStandardStreams = false
        }
    }

    publishPlugin {
        // Supplied by CI from the JETBRAINS_MARKETPLACE_TOKEN secret. Never hardcode this.
        token.set(providers.environmentVariable("PUBLISH_TOKEN"))
        channels.set(listOf(providers.gradleProperty("pluginChannel").get()))
    }
}

dependencies {
    implementation("com.googlecode.soundlibs:jlayer:1.0.1.4")

    testImplementation("junit:junit:4.13.2")
}
