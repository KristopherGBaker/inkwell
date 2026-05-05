(function () {
  'use strict';

  if (!('clipboard' in navigator) || typeof navigator.clipboard.writeText !== 'function') {
    return;
  }

  function buildButton() {
    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'code-copy-button';
    button.dataset.state = 'idle';
    button.setAttribute('aria-label', 'Copy code to clipboard');
    button.textContent = 'Copy';
    return button;
  }

  function setState(button, state) {
    button.dataset.state = state;
    if (state === 'copied') {
      button.textContent = 'Copied';
    } else if (state === 'error') {
      button.textContent = 'Error';
    } else {
      button.textContent = 'Copy';
    }
  }

  function attach(pre) {
    if (pre.dataset.codeCopyAttached === 'true') {
      return;
    }
    pre.dataset.codeCopyAttached = 'true';
    var code = pre.querySelector('code');
    if (!code) {
      return;
    }

    var wrapper;
    if (pre.parentElement && pre.parentElement.classList.contains('code-copy-wrapper')) {
      wrapper = pre.parentElement;
    } else {
      wrapper = document.createElement('div');
      wrapper.className = 'code-copy-wrapper';
      pre.parentNode.insertBefore(wrapper, pre);
      wrapper.appendChild(pre);
    }

    var button = buildButton();
    wrapper.appendChild(button);

    button.addEventListener('click', function () {
      var text = code.textContent || '';
      navigator.clipboard.writeText(text).then(
        function () {
          setState(button, 'copied');
          setTimeout(function () { setState(button, 'idle'); }, 1500);
        },
        function () {
          setState(button, 'error');
          setTimeout(function () { setState(button, 'idle'); }, 2000);
        }
      );
    });
  }

  function run() {
    document.querySelectorAll('pre').forEach(function (pre) {
      if (pre.classList.contains('mermaid')) {
        return;
      }
      attach(pre);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
  } else {
    run();
  }
})();
