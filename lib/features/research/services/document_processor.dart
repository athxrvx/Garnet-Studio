import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; 
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path; 

import '../models/research_models.dart';

class DocumentProcessor {
  Future<List<DocumentChunk>> processFile(File file, String workspaceId, String documentId) async {
    final ext = path.extension(file.path).toLowerCase();
    
    // 1. Extract Text based on type
    String content = '';
    
    try {
      if (ext == '.pdf') {
        content = await _extractPdfText(file);
      } else if (ext == '.zip') {
        // For Zip, we might want to return chunks for multiple files.
        // But our return type is List<DocumentChunk> which is fine.
        // We probably want to annotate which file inside the zip it came from, 
        // but for now let's just concatenating text or handle basic extracting.
        return await _processZip(file, workspaceId, documentId);
      } else if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
        content = "[Image: ${path.basename(file.path)}]\n(Image processing not yet enabled)";
      } else {
        // Default to text (covers values like .txt, .md, .dart, .json, .yaml etc)
        // Check if binary? Use try-catch on readAsString
        content = await file.readAsString();
      }
    } catch (e) {
      content = "Error processing file: $e"; 
    }

    return _chunkText(content, workspaceId, documentId);
  }

  Future<List<DocumentChunk>> processUrl(String url, String workspaceId, String documentId) async {
      String content = '';
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
            final document = parse(response.body);
            // Simple text extraction from HTML
            content = document.body?.text ?? "No content found";
            // Reduce whitespace
            content = content.replaceAll(RegExp(r'\s+'), ' ').trim();
            content = "Source URL: $url\n\n$content";
        } else {
            content = "Error fetching URL: ${response.statusCode}";
        }
      } catch (e) {
          content = "Error processing URL: $e";
      }
      return _chunkText(content, workspaceId, documentId);
  }

  Future<String> _extractPdfText(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      return "Error reading PDF: $e";
    }
  }

  Future<List<DocumentChunk>> _processZip(File file, String workspaceId, String documentId) async {
      // Extract zip, process text files inside
      // This is expensive for large zips.
      List<DocumentChunk> allChunks = [];
      try {
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        for (final file in archive) {
            if (file.isFile) {
                final filename = file.name;
                final ext = path.extension(filename).toLowerCase();
                 if (['.txt', '.md', '.dart', '.js', '.py', '.json', '.yaml', '.xml', '.html', '.css'].contains(ext)) {
                     final content = String.fromCharCodes(file.content);
                     allChunks.addAll(_chunkText("File: $filename\n$content", workspaceId, documentId));
                 }
            }
        }
      } catch (e) {
         allChunks = _chunkText("Error processing zip: $e", workspaceId, documentId);
      }
      return allChunks;
  }

  List<DocumentChunk> _chunkText(String content, String workspaceId, String documentId) {
    // Clean Text
    final cleanContent = content.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Chunking 
    const int chunkSize = 1000; // Increased chunk size for better context
    const int overlap = 100; // Add overlap for better context continuity
    List<DocumentChunk> chunks = [];
    int index = 0;
    
    if (cleanContent.isEmpty) return [];

    // Use a while loop for overlapping chunks
    int i = 0;
    while (i < cleanContent.length) {
      int end = (i + chunkSize < cleanContent.length) ? i + chunkSize : cleanContent.length;
      String chunkText = cleanContent.substring(i, end);
      
      chunks.add(DocumentChunk(
        id: const Uuid().v4(),
        documentId: documentId,
        workspaceId: workspaceId,
        content: chunkText,
        chunkIndex: index++, 
        embedding: null,
      ));
      
      i += (chunkSize - overlap); // Move forward by size minus overlap
      if (i >= cleanContent.length && end < cleanContent.length) break; // Safety break
    }
    return chunks;
  }
}

