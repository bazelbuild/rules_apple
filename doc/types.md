# Related types

This file documents other special types used by the Apple Bazel rules.

<a name="apple_product_type"></a>
## apple_product_type

A `struct` containing product type identifiers used by special application and
extension types.

Some applications and extensions, such as Messages Extensions and
Sticker Packs in iOS 10, receive special treatment when building (for example,
some product types bundle a stub executable instead of a user-defined binary,
and some pass extra arguments to tools like the asset compiler). These
behaviors are captured in the product type identifier. The product types
currently supported are:

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Product types</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>messages_application</code></td>
      <td>
        <p>Applies to <code>ios_application</code> targets built for iOS 10 and
        above.</p>
        <p>A "stub" application used to distribute a standalone Messages
        Extension or Sticker Pack. This application <strong>must</strong>
        include an <code>ios_extension</code> whose product type is
        <code>messages_extension</code> or
        <code>messages_sticker_pack_extension</code> (or it can include both).
        </p>
        <p>This product type does not contain a user-provided binary; any code
        in its <code>deps</code> will be ignored.</p>
        <p>This stub application is not displayed on the home screen and its
        features are only accessible through the Messages user interface. If
        you are building a Messages Extension or Sticker Pack as part of a
        larger application that is launchable, do not use this product type;
        simply add those extensions to the existing application.</p>
      </td>
    </tr>
    <tr>
      <td><code>messages_extension</code></td>
      <td>
        <p>Applies to <code>ios_extension</code> targets built for iOS 10 and
        above.</p>
        <p>An extension that integrates custom behavior into the Apple Messages
        application. Such extensions can present a custom user interface in the
        keyboard area of the app and interact with users' conversations.</p>
      </td>
    </tr>
    <tr>
      <td><code>messages_sticker_pack_extension</code></td>
      <td>
        <p>Applies to <code>ios_extension</code> targets built for iOS 10 and
        above.</p>
        <p>An extension that defines custom sticker packs for the Apple
        Messages app. Stickers are provided by including an asset catalog
        named <code>*.xcstickers</code> in the extension's
        <code>asset_catalogs</code> attribute.</p>
        <p>This product type does not contain a user-provided binary; any
        code in its <code>deps</code> will be ignored.</p>
      </td>
    </tr>
  </tbody>
</table>

Example usage:

```python
load("@build_bazel_rules_apple//apple:ios.bzl",
     "apple_product_type", "ios_application", "ios_extension")

ios_application(
    name = "StickerPackApp",
    extensions = [":StickerPackExtension"],
    product_type = apple_product_type.messages_application,
    # other attributes...
)

ios_extension(
    name = "StickerPackExtension",
    product_type = apple_product_type.messages_sticker_pack_extension,
    # other attributes...
)
```
