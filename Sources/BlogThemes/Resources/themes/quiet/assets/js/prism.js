(function () {
  var keywords = {
    swift: [
      "actor", "any", "as", "associatedtype", "async", "await", "break", "case", "catch",
      "class", "continue", "defer", "do", "else", "enum", "extension", "false", "for",
      "func", "guard", "if", "import", "in", "init", "inout", "is", "let", "nil",
      "private", "protocol", "public", "return", "self", "some", "static", "struct",
      "switch", "throws", "throw", "true", "try", "typealias", "var", "where", "while"
    ],
    bash: [
      "case", "do", "done", "elif", "else", "esac", "fi", "for", "function", "if",
      "in", "then", "until", "while"
    ],
    shell: [
      "case", "do", "done", "elif", "else", "esac", "fi", "for", "function", "if",
      "in", "then", "until", "while"
    ],
    json: ["true", "false", "null"],
    javascript: [
      "async", "await", "break", "case", "catch", "class", "const", "continue", "default",
      "else", "export", "false", "finally", "for", "function", "if", "import", "let",
      "new", "null", "return", "switch", "this", "throw", "true", "try", "var", "while"
    ]
  };

  function escapeHTML(value) {
    return value
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function wrap(className, value) {
    return '<span class="token ' + className + '">' + escapeHTML(value) + '</span>';
  }

  function keywordPattern(language) {
    var words = keywords[language] || keywords.javascript;
    return words.join("|");
  }

  function highlightSegment(segment, language) {
    var pattern = new RegExp(
      "\\b(" + keywordPattern(language) + ")\\b" +
      "|\\b(\\d+(?:\\.\\d+)?)\\b" +
      "|\\b([A-Za-z_][\\w]*)\\s*(?=\\()" +
      "|(&amp;&amp;|\\|\\||-&gt;|=&gt;|[=+\\-*\\/%!?]+)",
      "g"
    );

    return escapeHTML(segment).replace(pattern, function (match, keyword, number, functionName, operator) {
      if (keyword) {
        if (keyword === "true" || keyword === "false") {
          return '<span class="token boolean">' + keyword + '</span>';
        }
        if (keyword === "nil" || keyword === "null") {
          return '<span class="token null">' + keyword + '</span>';
        }
        return '<span class="token keyword">' + keyword + '</span>';
      }
      if (number) {
        return '<span class="token number">' + number + '</span>';
      }
      if (functionName) {
        return '<span class="token function">' + functionName + '</span>';
      }
      if (operator) {
        return '<span class="token operator">' + operator + '</span>';
      }
      return match;
    });
  }

  function highlight(code, language) {
    var tokens = [];
    var protectedCode = code.replace(/\/\*[\s\S]*?\*\/|\/\/.*|#.*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`/g, function (match) {
      var type = /^\/\*|^\/\/|^#/.test(match) ? "comment" : "string";
      var index = tokens.push(wrap(type, match)) - 1;
      return "\u0000" + index + "\u0000";
    });

    return protectedCode.split(/(\u0000\d+\u0000)/g).map(function (part) {
      var match = part.match(/^\u0000(\d+)\u0000$/);
      if (match) {
        return tokens[Number(match[1])] || "";
      }
      return highlightSegment(part, language);
    }).join("");
  }

  function languageFor(code) {
    var match = Array.prototype.find.call(code.classList, function (className) {
      return className.indexOf("language-") === 0;
    });
    return match ? match.slice("language-".length).toLowerCase() : "text";
  }

  function highlightAll() {
    document.querySelectorAll('pre code[class*="language-"]').forEach(function (code) {
      var pre = code.closest("pre");
      if (!pre || pre.classList.contains("mermaid") || pre.classList.contains("shiki") || code.dataset.highlighted === "true") {
        return;
      }
      var language = languageFor(code);
      if (language === "mermaid" || language === "text") {
        return;
      }
      code.innerHTML = highlight(code.textContent || "", language);
      code.dataset.highlighted = "true";
    });
  }

  window.Prism = window.Prism || {};
  window.Prism.highlightAll = highlightAll;
  window.addEventListener("DOMContentLoaded", highlightAll);
})();
