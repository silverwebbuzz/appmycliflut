import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/providers.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';

/// GST invoice / credit note — `store_orders.php?action=invoice`.
///
/// The page is HTML and requires the Bearer header, so it opens in an
/// in-app WebView with the header on the initial request. An external
/// browser would have no token. The header is only attached for the API
/// host, never for a URL pointing anywhere else.
class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_supported) _open();
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(widget.url);
    final apiHost = Uri.parse(kApiBaseUrl).host;
    if (uri == null || uri.host != apiHost) {
      setState(() {
        _loading = false;
        _error = 'This document link is not valid.';
      });
      return;
    }
    final token = await ref.read(sessionStorageProvider).readToken();
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (e) {
          if (mounted && e.isForMainFrame != false) {
            setState(() {
              _loading = false;
              _error = 'Could not load the document (${e.description}).';
            });
          }
        },
      ));
    await controller.loadRequest(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (mounted) setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Invoice';
    if (!_supported) {
      return AppSubPage(
        title: title,
        fallbackRoute: '/shop/orders',
        children: const [
          AppPlaceholder(
            icon: AppGlyph.document,
            title: 'Open this in the app',
            message: 'Invoices open inside the Android or iOS app.',
          ),
        ],
      );
    }
    return AppSubPage(
      title: title,
      fallbackRoute: '/shop/orders',
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: AppNote(_error!, tone: AppTone.err),
            )
          else if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
