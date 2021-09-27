// Copyright (c) 2021 Mantano. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:fimber/fimber.dart';
import 'package:mno_commons/extensions/strings.dart';
import 'package:mno_shared/epub.dart';
import 'package:mno_shared/fetcher.dart';
import 'package:mno_shared/mediatype.dart';
import 'package:mno_shared/publication.dart';
import 'package:path/path.dart' as p;

/// Inject the XPUB CSS and JS links in a publication HTML resources.
class HtmlInjector {
  /// The [publication] that is the context for the HTML injection.
  final Publication publication;

  /// Create an instance [HtmlInjector] for a [publication].
  HtmlInjector(this.publication);

  /// Inject CSS and JS links if the resource is HTML.
  Resource transform(Resource resource) => LazyResource(() async {
        Link link = await resource.link();
        if (link.mediaType.isHtml) {
          return _InjectHtmlResource(publication, resource);
        }
        return resource;
      });
}

class _InjectHtmlResource extends TransformingResource {
  final Publication publication;

  _InjectHtmlResource(this.publication, Resource resource) : super(resource);

  @override
  Future<ResourceTry<ByteData>> transform(ResourceTry<ByteData> data) async {
    Link l = await link();
    EpubLayout renditionLayout = publication.metadata.presentation.layoutOf(l);
    return (await resource.readAsString(
            charset: l.mediaType.charset ?? Charsets.utf8))
        .mapCatching((html) {
      html = _injectLinks(html, renditionLayout);
      html = _wrapHtmlContent(html, renditionLayout);
      return html.toByteData();
    });
  }

  /// Injects the links before </head>.
  String _injectLinks(String html, EpubLayout renditionLayout) {
    int headIndex = html.indexOf('</head>');
    if (headIndex == -1) {
      Fimber.d("Can't find </head> to inject HTML links");
      return html;
    }

    String linksHtml = _createLinksToInjectHtml(renditionLayout);

    return "${html.substring(0, headIndex)}\n$linksHtml\n${html.substring(headIndex)}";
  }

  /// Builds the HTML for the list of links to be injected in <head>
  String _createLinksToInjectHtml(EpubLayout renditionLayout) =>
      _createLinksToInject(renditionLayout)
          .map((path) {
            switch (p.extension(path).toLowerCase()) {
              case '.css':
                return '<link href="$path" rel="stylesheet" />';
              case '.js':
                return '<script type="text/javascript" src="$path"></script>';
              default:
                Fimber.d("Can't HTML inject path: $path");
                return null;
            }
          })
          .where((l) => l != null)
          .join('\n');

  /// Link's href to be injected in <head> for the given [Link] resource.
  /// The file extension is used to know if it's a JS or CSS.
  List<String> _createLinksToInject(EpubLayout renditionLayout) => [
        '/css/ReadiumCSS-before.css',
        '/css/ReadiumCSS-default.css',
        '/css/ReadiumCSS-after.css',
        if (renditionLayout == EpubLayout.fixed) '/js/rreadium-fixed.js',
        if (renditionLayout == EpubLayout.reflowable) ...[
          '/js/readium-reflowable.js'
        ],
      ];

  /// Wraps the HTML for pagination.
  String _wrapHtmlContent(String html, EpubLayout renditionLayout) {
    html = html.replaceFirst('</head>',
        '</head><meta name="viewport" content="width=device-width, initial-scale=1" />');

    // html = _insertString(
    //     '(<body[^>]*>)', html, '<style>body {padding-top:30px}</style>', false);

    if (renditionLayout == EpubLayout.reflowable) {
      html = _insertString('(<body[^>]*>)', html,
          '<div class="xpub_container"><div id="xpub_contenuSpineItem">', true);
      html = _insertString('(</body>)', html,
          '</div><div id="xpub_paginator"></div></div>', false);
    }
    return html;
  }

  String _insertString(
      String pattern, String content, String contentToAdd, bool insertAfter) {
    Match? match = _matchRegex(pattern, content);
    if (match == null) {
      Fimber.d("Can't find $pattern to insert $contentToAdd");
      return content;
    }
    int insertionPoint = insertAfter ? match.end : match.start;
    return content.substring(0, insertionPoint) +
        contentToAdd +
        content.substring(insertionPoint);
  }

  Match? _matchRegex(String pattern, String html) {
    RegExp exp = RegExp(pattern);
    Match? startBody = exp.firstMatch(html);
    return startBody;
  }
}
