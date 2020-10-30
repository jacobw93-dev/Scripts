function onOpen() {
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var searchMenuEntries = [{
        name: "Create List from Folder",
        functionName: "start"
    }];
    ss.addMenu("Document List", searchMenuEntries);
}


function start() {
    var sheet = SpreadsheetApp.getActiveSheet();
    sheet.clear();
    sheet.appendRow(["Name", "FileID", "Date", "Size (MB)", "URL", "Description", "Type", "Original Name"]);

    var folderId = Browser.inputBox("Enter Folder ID:");
    var folder = DriveApp.getFolderById(folderId).getFolders();

    if (folder.hasNext()) {
        processFolder(folder);
    } else {
        Browser.msgBox('Folder not found!');
    }


    function processFolder(folder) {
        while (folder.hasNext()) {
            var f = folder.next();
            var contents = f.getFiles();
            addFilesToSheet(contents, f);
            var subFolder = f.getFolders();
            processFolder(subFolder);
        }
    }
  function Revision_Name(passFileId) {
    var fileId = passFileId;
    var revisions = Drive.Revisions.list(fileId);
    if (revisions.items && revisions.items.length > 0) {
      for (var i = 0; i < revisions.items.length; i++) {
        var revision = revisions.items[i];
        return revision.originalFilename;
      }
    } else {
      Logger.log('No revisions found.');
    }
  }  

    function addFilesToSheet(files, folder) {
        var data;
        var folderName = folder.getName();
        while (files.hasNext()) {
            var file = files.next();
          var passFileId = file.getId();
            Logger.log(file.getName());

            sheet.appendRow([
              file.getName(),
              passFileId,
              file.getDateCreated(),
              parseFloat(file.getSize()/1024/1024).toFixed(2),
              file.getUrl(),
              file.getDescription(),
              file.getMimeType(),
              Revision_Name(passFileId)
            ]);
        }
    }

    
}