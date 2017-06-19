# inno_setup

Inno Setup is a free installer system for Windows available at (http://www.jrsoftware.org/isinfo.php). This helper fills in a template `.iss` file with the files and folders in your application each time you package your application.

## Contents

* [Activate the font_loader framework helper](#activate-the-font_loader-framework-helper)
* [Adding a font to your application](#adding-a-font-to-your-application)

## Activate the font_loader framework helper

To add the Font Loader helper to your application add it under the `helpers` section of the `app.yml` file:

```
# app.yml

helpers:
  - folder: ./helpers
  - filename: "./helpers/inno_setup"
```

## Adding a font to your application

You configure fonts by adding a `fonts` key to the `app.yml` file. The following example loads the PasswordEntry.ttf font when your application is launched. The `global` property is optional and defaults to `false` which means the font will only be available to your application. If true then the font will be available to all applications on the computer.

```
# app.yml

inno setup:
  - filename: ../installer_files/MyApp.iss
```

When you package your application the `.iss` file will be copied into the application folder.
