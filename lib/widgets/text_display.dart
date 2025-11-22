import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextDisplay extends StatefulWidget {
  final String text;
  final TextEditingController? controller;
  final bool isEditing;
  final VoidCallback? onTextChanged;

  const TextDisplay({
    super.key,
    required this.text,
    this.controller,
    this.isEditing = false,
    this.onTextChanged,
  });

  @override
  State<TextDisplay> createState() => _TextDisplayState();
}

class _TextDisplayState extends State<TextDisplay> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.text);
    _focusNode = FocusNode();

    // Select all text when entering edit mode
    if (widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectAllAndFocus();
      });
    }
  }

  @override
  void didUpdateWidget(TextDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle entering edit mode
    if (!oldWidget.isEditing && widget.isEditing) {
      _selectAllAndFocus();
    }

    // Handle exiting edit mode
    if (oldWidget.isEditing && !widget.isEditing) {
      _focusNode.unfocus();
    }

    // Update text if it changed externally
    if (oldWidget.text != widget.text && widget.controller == null) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _selectAllAndFocus() {
    if (mounted && _controller.text.isNotEmpty) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      _focusNode.requestFocus();
    }
  }

  void _handleTextChanged() {
    widget.onTextChanged?.call();
  }

  void _handleTap() {
    if (!widget.isEditing && mounted) {
      // Copy all text when tapping in read-only mode
      Clipboard.setData(ClipboardData(text: _controller.text));
      HapticFeedback.lightImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All text copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isEditing ? Colors.blue : Colors.grey[300]!,
          width: widget.isEditing ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.isEditing ? _buildEditableText() : _buildReadOnlyText(),
    );
  }

  Widget _buildEditableText() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(
        fontSize: 16,
        height: 1.5,
      ),
      decoration: const InputDecoration(
        hintText: 'Edit your extracted text here...',
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(16),
      ),
      onChanged: (value) => _handleTextChanged(),
      onSubmitted: (value) => _handleTextChanged(),
    );
  }

  Widget _buildReadOnlyText() {
    return GestureDetector(
      onTap: _handleTap,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _controller.text,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

// Empty text display widget for when no text is available
class EmptyTextDisplay extends StatelessWidget {
  final VoidCallback? onRetry;

  const EmptyTextDisplay({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.text_snippet_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No text extracted',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The image didn\'t contain any readable text.\nPlease try with a clearer image.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}