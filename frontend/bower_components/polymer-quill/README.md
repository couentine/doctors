[![Published on webcomponents.org](https://img.shields.io/badge/webcomponents.org-published-green.svg)](https://www.webcomponents.org/element/arsnebula/polymer-quill)
[![Polymer Version](https://img.shields.io/badge/polymer-v2-blue.svg)](https://www.polymer-project.org)
[![Gitter Chat](https://badges.gitter.im/org.png)](https://gitter.im/arsnebula/webcomponents)
[![Become a Patreon](https://img.shields.io/badge/patreon-support_us-orange.svg)](https://www.patreon.com/arsnebula)

# \<polymer-quill\>

A custom build of the [Quill Rich Text Editor](https://quilljs.com) to support Polymer web components.

* Custom build of Quill that supports editors hosted in Shadow DOM
* Choose from two imports: core or the full Quill library
* Quill stylesheets provided as style modules that can be included in Polymer custom elements

> This package (and version) will be updated to remain in sync with the offical Quill project as new releases are available.

## Installation

```sh
$ bower install -S arsnebula/polymer-quill
```

## Getting Started

The default package includes the full library, core styles, and the snow and bubble themes as style modules:

```html
<link rel="import" href="/bower_components/polymer-quill/polymer-quill.html">
```

To only work with the core library and core styles, import the core package:

```html
<link rel="import" href="/bower_components/polymer-quill/polymer-quill-core.html">
```

Include the relevent style modules in your custom element template. You must import the `quill-core` styles. To include a Quill theme, include the `quill-snow` and/or the `quill-bubble` style modules. Add additional styles to customize as necessary.

The following is a demonstration of a basic element with a Quill editor.

```html
<link rel="import" href="/bower_components/polymer-quill/polymer-quill.html">

<dom-module id="my-editor">
  <template>
    <style include="quill-core quill-snow"></style>
    <div id="editor"></div>
  </template>
  <script>
    class MyEditor extends Polymer.Element {
      static get is() { return 'my-editor' }

      ready() {
        super.ready()
        this.editor = new Quill(this.$.editor, {
          theme: 'snow'
        })
      }
    } 
  </script> 
</dom-module>
```

*For more information, see the [Quill Documentation](https://quilljs.com/docs).*

## Contributing

We welcome and appreciate feedback from the community. Here are a few ways that you can show your appreciation for this package:

* Give us a **Star on GitHub** from either [webcomponents.org](https://www.webcomponents.org/element/arsnebula/nebula-element-mixin) or directly on [GitHub](https://github.com/arsnebula/nebula-element-mixin).

* Submit a feature request, or a defect report on the [Issues List](https://www.webcomponents.org/element/arsnebula/nebula-element-mixin/issues).

* Become a [Patreon](https://www.patreon.com/arsnebula). It takes a lot of time and effort to develop, document, test and support the elements in our [Nebula Essentials](https://www.webcomponents.org/collection/arsnebula/nebula-essentials) collection. Your financial contribution will help ensure that our entire collection continues to grow and improve.

If you are a developer, and are interested in making a code contribution, consider opening an issue first to describe the change, and discuss with the core repository maintainers. Once you are ready, prepare a pull request:

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request :D

## Change Log

See [CHANGELOG](/CHANGELOG.md)

## License

See [LICENSE](/LICENSE.md)