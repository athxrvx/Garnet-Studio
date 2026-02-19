import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';

class WebSearchService {
  final _unescape = HtmlUnescape();

  Future<List<String>> search(String query) async {
    try {
      final safeQuery = Uri.encodeComponent(query);
      // Using html.duckduckgo.com for simpler HTML parsing
      final url = Uri.parse('https://html.duckduckgo.com/html/?q=$safeQuery');
      
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      });

      if (response.statusCode == 200) {
        final document = html.parse(response.body);
        final results = document.querySelectorAll('.result__body');
        
        List<String> extractedInfo = [];
        
        if (results.isEmpty) {
             // Fallback or debug check
             // Sometimes DDG returns a different structure or captcha
             print("Web Search: No results found in DOM. Body length: ${response.body.length}");
        }

        for (var result in results.take(6)) { // Increased result count
          final titleElement = result.querySelector('.result__title');
          final snippetElement = result.querySelector('.result__snippet');
          final urlElement = result.querySelector('.result__url');
          
          if (titleElement != null && snippetElement != null) {
            String title = titleElement.text.trim();
            String snippet = snippetElement.text.trim();
            String link = urlElement?.text.trim() ?? '';
            
            extractedInfo.add('Title: $title\nSnippet: $snippet\nSource: $link');
          }
        }
        return extractedInfo;
      } else {
         print("Web Search Error: ${response.statusCode}");
      }
      return [];
    } catch (e) {
      print('Search Error: $e');
      return ["Error performing search: $e"];
    }
  }

  /// Performs a redundant/recursive search for deep research
  Future<String> deepResearch(String query, {int depth = 1}) async {
    // 1. Initial Search
    final initialResults = await search(query);
    if (initialResults.isEmpty) return "No results found.";
    
    // For a real deep research, we would visit the links. 
    // Here we will summarize the search snippets.
    
    StringBuffer researchData = StringBuffer();
    researchData.writeln("Research Report for: $query\n");
    researchData.writeln("## Initial Findings");
    for (var res in initialResults) {
      researchData.writeln("- $res\n");
    }
    
    return researchData.toString();
  }
}
