(function () {
  var filesInput = document.getElementById('files');
  var pinInput = document.getElementById('pin');
  var sendButton = document.getElementById('send');
  var statusList = document.getElementById('status');

  function addStatus(text) {
    var item = document.createElement('li');
    item.textContent = text;
    statusList.appendChild(item);
  }

  function setBusy(busy) {
    filesInput.disabled = busy;
    pinInput.disabled = busy;
    sendButton.disabled = busy;
  }

  function fileId(index) {
    if (window.crypto && window.crypto.randomUUID) {
      return window.crypto.randomUUID();
    }
    return 'browser-file-' + index + '-' + Date.now();
  }

  function fileType(file) {
    return file.type || 'application/octet-stream';
  }

  function buildPreparePayload(files) {
    var fileMap = {};
    files.forEach(function (file, index) {
      var id = fileId(index);
      file._iphone2winId = id;
      fileMap[id] = {
        id: id,
        fileName: file.name || ('file-' + (index + 1)),
        size: file.size,
        fileType: fileType(file),
        metadata: {
          modified: file.lastModified ? new Date(file.lastModified).toISOString() : null,
          accessed: null
        }
      };
    });

    return {
      info: {
        alias: 'iPhone Browser',
        version: '2.0',
        deviceModel: navigator.platform || 'Browser',
        deviceType: 'mobile',
        fingerprint: 'browser-upload',
        port: 0,
        protocol: 'http',
        download: false
      },
      files: fileMap
    };
  }

  async function prepareUpload(files, pin) {
    var url = '/api/localsend/v2/prepare-upload';
    if (pin) {
      url += '?pin=' + encodeURIComponent(pin);
    }

    var response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(buildPreparePayload(files))
    });

    if (response.status === 401) {
      throw new Error('PIN required or invalid.');
    }
    if (response.status === 403) {
      throw new Error('Transfer rejected by receiver.');
    }
    if (response.status === 409) {
      throw new Error('Receiver is busy with another transfer.');
    }
    if (!response.ok) {
      throw new Error('Prepare failed: ' + response.status);
    }

    return await response.json();
  }

  async function uploadFile(file, sessionId, token) {
    var url = '/api/localsend/v2/upload'
      + '?sessionId=' + encodeURIComponent(sessionId)
      + '&fileId=' + encodeURIComponent(file._iphone2winId)
      + '&token=' + encodeURIComponent(token);

    var response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': fileType(file)
      },
      body: file
    });

    if (!response.ok) {
      throw new Error('Upload failed: ' + response.status);
    }
  }

  sendButton.addEventListener('click', async function () {
    statusList.innerHTML = '';
    var files = Array.prototype.slice.call(filesInput.files || []);
    var pin = pinInput.value.trim();

    if (files.length === 0) {
      addStatus('Choose at least one file.');
      return;
    }

    setBusy(true);
    try {
      addStatus('Waiting for receiver approval...');
      var prepared = await prepareUpload(files, pin);
      addStatus('Receiver accepted. Uploading ' + files.length + ' file(s)...');

      for (var i = 0; i < files.length; i++) {
        var file = files[i];
        var token = prepared.files[file._iphone2winId];
        if (!token) {
          addStatus('Skipped: ' + file.name);
          continue;
        }

        addStatus('Uploading: ' + file.name);
        await uploadFile(file, prepared.sessionId, token);
      }

      addStatus('Complete.');
    } catch (error) {
      addStatus(error && error.message ? error.message : String(error));
    } finally {
      setBusy(false);
    }
  });
})();
