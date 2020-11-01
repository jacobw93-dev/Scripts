function onOpen1() {
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
  sheet.getRange('A1').activate();
  sheet.appendRow(["Name", "Original Name", "FileID", "Date", "Size (MB)", "URL", "Description", "Type"]);
  
  var folderName = Browser.inputBox("Enter Folder Name:");
  var folder = DriveApp.getFoldersByName(folderName);
  //var folder = DriveApp.getFolderById(folderId).getFolders();
  
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
    var spreadsheet = SpreadsheetApp.getActive();
    while (files.hasNext()) {
      
      var file = files.next();
      var passFileId = file.getId();
      while (file.getName() != Revision_Name(passFileId)) {
        
        Logger.log("File Name: " + "'" + file.getName() + "'" + " renamed to: " + "'" + Revision_Name(passFileId) + "'" );
        sheet.appendRow([
          file.getName(),          
          Revision_Name(passFileId),
          passFileId,
          file.getDateCreated(),
          parseFloat(file.getSize()/1024/1024).toFixed(3),
          file.getUrl(),
          file.getDescription(),
          file.getMimeType()
        ]);
        
        file.setName(Revision_Name(passFileId));
        spreadsheet.getRange('A' + (spreadsheet.getLastRow()+1)).activate();
      }
      Utilities.sleep(100);
    }
  }
  
  
}