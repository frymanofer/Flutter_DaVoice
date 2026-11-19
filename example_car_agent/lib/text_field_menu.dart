import 'package:flutter/material.dart';

/// The copy/paste menu of the app's text fields: Flutter's own toolbar. The
/// default iOS system menu (SystemContextMenu) fails with "Attempted to show
/// while another instance was still visible" when two fields' menus overlap.
Widget textFieldContextMenu(BuildContext context, EditableTextState editableTextState) =>
    AdaptiveTextSelectionToolbar.editableText(editableTextState: editableTextState);
