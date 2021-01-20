Attribute VB_Name = "MyTools"
Public Sub AddShadows()


Set insp = Application.ActiveInspector
    If insp.CurrentItem.Class = olMail Then
        Set Mail = insp.CurrentItem
            If insp.EditorType = olEditorWord Then
                Set wordActiveDocument = Mail.GetInspector.WordEditor

                For Each MyPic In wordActiveDocument.InlineShapes
                    With MyPic.Shadow
                      .Style = msoShadowStyleOuterShadow
                      .Type = msoShadow25
                      .Size = 100
                      .Transparency = 0.3
                      .ForeColor.RGB = RGB(0, 0, 0)
                    End With
                Next MyPic
            
            End If
    End If
End Sub

Public Sub ForwardEmail(Item As Outlook.MailItem)

Dim objForward As Outlook.MailItem, oEmailCopy As Outlook.MailItem, SentFolder As Outlook.Folder
' Dim oRule As Outlook.Rule

Set SentFolder = Outlook.Application.GetNamespace("MAPI").GetDefaultFolder(olFolderSentMail).Folders("Private")

Set objForward = Item.Forward
    With objForward
        .Subject = objForward.Subject
        .Recipients.Add "jakub.walczak.dhl@gmail.com"
        .HTMLBody = objForward.HTMLBody
        ' .DeleteAfterSubmit = True
        Set .SaveSentMessageFolder = SentFolder
        .UnRead = False
        .Send
    End With

' Set oRule = Outlook.Application.Session.DefaultStore.GetRules.Item("jawalcza")
' Set SentFolder = Session.GetDefaultFolder(5)
' oRule.Execute ShowProgress:=False, Folder:=Session.GetDefaultFolder(olFolderSentMail), IncludeSubfolders:=False
    
End Sub

Public Sub Reply_with_Template()

Dim Original As MailItem, Reply As MailItem, myItem As Outlook.MailItem, myInspector As Outlook.Inspector, myDoc As Word.Document

Set Original = ActiveExplorer.Selection(1).Reply
Set Original1 = ActiveExplorer.Selection(1)
Set myItem = _
    CreateItemFromTemplate("C:\Users\jawalcza\AppData\Roaming\Microsoft\Szablony\SAP_LOGON_config.oft")

    myItem.Display
    Set myInspector = Application.ActiveInspector
    Set myDoc = myInspector.WordEditor

 myDoc.Bookmarks("_MailAutoSig").Range.Delete
 
Set Reply = myItem

Reply.Subject = Original.Subject
Reply.HTMLBody = "<p style='font-family:calibri;font-size:11'>" & Reply.HTMLBody & "</p>" & Original.HTMLBody
Reply.HTMLBody = Replace(Reply.HTMLBody, signature, "")



If Original1.SenderEmailAddress <> "G.Servicenow@dhl.com" Then
    Reply.To = Original1.SenderEmailAddress
End If
Reply.Recipients.ResolveAll
Reply.Display
    
End Sub


