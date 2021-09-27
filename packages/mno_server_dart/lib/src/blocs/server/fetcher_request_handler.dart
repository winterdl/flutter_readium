// Copyright (c) 2021 Mantano. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mno_server/mno_server.dart';
import 'package:mno_shared/fetcher.dart';
import 'package:mno_shared/publication.dart';
import 'package:universal_io/io.dart';

import 'html_injector.dart';

/// Serves the resources of a [Publication] [Fetcher] from a [ServerBloc].
class FetcherRequestHandler extends RequestHandler {
  /// The [publication] where to find the resource
  final Publication publication;
  final HtmlInjector _htmlInjector;

  /// Creates an instance of [FetcherRequestHandler] for a [publication].
  ///
  /// A [transformData] parameter is optional.
  FetcherRequestHandler(this.publication)
      : _htmlInjector = HtmlInjector(publication);

  Fetcher get _fetcher => publication.fetcher;

  @override
  Future<bool> handle(int requestId, HttpRequest request, String href) async {
    Link? link = publication.linkWithHref(href);
    if (link == null) {
      return false;
    }
    Resource resource = _fetcher.get(link);
    if (!(await _exist(resource))) {
      return false;
    }

    print(link.mediaType);

    await sendResource(
      request,
      resource: _htmlInjector.transform(resource),
      mediaType: link.mediaType,
    );

    return true;
  }

  Future<bool> _exist(Resource resource) async =>
      (await resource.length()).isSuccess;
}
