/**
====================================================================================================

  File Name     :     AWS_FileUploadDownloadCalloutCtrl
  Created By    :     Vishal Thube
  Created Date  :     21-01-2025
  Purpose       :     This class contains methods for interacting with the AWS S3 service to upload, 
                     download, move, and delete files. It also includes methods for fetching file names 
                     from S3 and saving files as attachments in Salesforce.

  CHANGE HISTORY: 
     
====================================================================================================
*/



global class AWS_FileUploadDownloadCalloutCtrl{

    
    
    //SendIrisXML.uploadFile('00PDC00000G6Mi22AF', 'FromEGMS/To_be_Transmitted');
   public static Boolean uploadFile(Id recordId, String folderName) {
        List<Attachment> atts = [SELECT Name, Body, ParentId, ContentType 
                                 FROM Attachment 
                                 WHERE ParentId = :recordId 
                                 ORDER BY CreatedDate DESC LIMIT 1];
    
        if (!atts.isEmpty()) {
            Attachment att = atts[0];
    
            String attachmentBody = att.Body.toString();
           // String encodedFileName = att.Name.replace(' ', '%20'); // URL encode the file name
            String encodedFileName = EncodingUtil.urlEncode(att.Name, 'UTF-8').replace('+', '%20');
            // Prepare HTTP request
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:AWS_S3/' + folderName + '/' + encodedFileName); 
            req.setMethod('PUT');
            req.setHeader('Content-Type',  att.ContentType); // Use the attachment's content type
            req.setHeader('x-amz-acl', 'private'); // Set appropriate ACL (private/public-read)
            req.setBody(attachmentBody);
    
            System.debug('HTTP Request: ' + req);
    
            // Send the HTTP request
            HttpResponse res = http.send(req);
    
            // Debug response
            System.debug('Response Status Code: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());
    
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                System.debug('File uploaded successfully to S3!');
                return true;
            } else {
                System.debug('File upload failed. Status: ' + res.getStatus());
                 return false;
            }
        } else {
            System.debug('No attachments found for the provided record ID.');
            return false;
        }
    }
    
    public static Map<String,object> downloadFile (String fileName,String folderName) {
        Map<String,object> responseMap= new Map<String,object> ();
        
            String encodedFileName = EncodingUtil.urlEncode(fileName, 'UTF-8').replace('+', '%20');

        
            //String encodedFileName = fileName.replace(' ', '%20'); // URL encode the file name
            // Prepare HTTP request
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:AWS_S3/' + folderName + '/' + encodedFileName ); 
            req.setMethod('GET');
            //req.setHeader('Content-Type','application/xml');
            system.debug('http req:::' + req);
            HTTPResponse res = http.send(req);
            
    
            // Debug response
            System.debug('Response Status Code: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());
    
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                String fileResponse =res.getBody(); 
                responseMap.put('isSuccess', true);
                responseMap.put('fileResponse', fileResponse );
                System.debug('File downloaded successfully from S3!'+ res.getBody());
            } else {
                System.debug('File downloaded failed. Status: ' + res.getStatus());
                String errorResponse = 'Status Code: ' + res.getStatusCode() + 
                           ', Status: ' + res.getStatus() + 
                           ', Body: ' + res.getBody();
    
                 responseMap.put('ErrorMessage', errorResponse); // Store as a string
                responseMap.put('isSuccess', false);
               
            }
      return responseMap;

    }
    public static Boolean moveFile(Id recordId, String fileName, String sourcePath, String destinationPath) {
   
            Boolean uploadSuccess = uploadFile(recordId, destinationPath);
            if (!uploadSuccess) {
                System.debug('File upload failed to destination path: ' + destinationPath);
                return false;
            }
    
            Boolean deleteSuccess = deleteFile(fileName, sourcePath);
            if (!deleteSuccess) {
                System.debug('File deletion failed from source path: ' + sourcePath);
                return false;
            }
            System.debug('File moved successfully from ' + sourcePath + ' to ' + destinationPath);
            return true;
       
    }


    public static Boolean deleteFile(String fileName, String folderName) {
        
            // URL encode the file name
           // String encodedFileName = fileName.replace(' ', '%20'); 
            String encodedFileName = EncodingUtil.urlEncode(fileName, 'UTF-8').replace('+', '%20');
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:AWS_S3/' + folderName + '/' + encodedFileName); 
            req.setMethod('DELETE');
            
            System.debug('HTTP Request: ' + req);
            
            HTTPResponse res = http.send(req);
            
            System.debug('Response Status Code: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 204) {
                System.debug('File deleted successfully from S3!');
                return true;
            } else {
                System.debug('File deletion failed. Status: ' + res.getStatus() + ', Body: ' + res.getBody());
                return false;
            }
         
    }

    
    public static void fetchS3fileNames() {
        List<String> fileNames = new List<String>();
        List<IntegrationHeader__c> insertList = new List<IntegrationHeader__c>();
        try{
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:AWS_S3');
            req.setMethod('GET');
            req.setHeader('Content-Type','application/xml');
            
            system.debug('http req:::' + req);
            Http http = new Http();
            HTTPResponse res = http.send(req);
            system.debug('res :::' + res );
            system.debug('res :::' + res.getStatus() );
    
            if (res.getStatusCode() == 200 || res.getStatusCode()==201) {
                fileNames = extractFileNames(res.getBody());
                for(String file : fileNames){
                    IntegrationHeader__c intHeader = new IntegrationHeader__c(Status__c = 'New', Direction__c = 'To EGMS', Filename__c = file);
                    insertList.add(intHeader);
                }
                insert insertList; 
            }else{
                GNT__ErrorLog__c errObj = new GNT__ErrorLog__c();
                errObj.GNT__Errordescription__c = String.valueOf(res);
                insert errObj;
            }
        }catch(Exception e){
            System.debug('Call Out Exception occurred '+e.getMessage());
            GNT__ErrorLog__c errObj = new GNT__ErrorLog__c();
            errObj.GNT__Errordescription__c = e.getMessage();
            insert errObj;
        }
        
        
    }
    
    public static List<String> extractFileNames(String responseBody){
        List<String> fileNames = new List<String>();
        List<IntegrationHeader__c> insertList = new List<IntegrationHeader__c>();
        // Parse the XML response
        Dom.Document doc = new Dom.Document();
        doc.load(responseBody);
    
        // Find and process the object names
        Dom.XmlNode root = doc.getRootElement();
        List<Dom.XmlNode> contents = root.getChildElements();
        
        for (Dom.XmlNode midChild: contents) {
            
            for(Dom.XmlNode content: midChild.getChildElements()){
                String tagName = content.getName();
                // Check if the node is a 'Key' element, which contains the object name
                if (tagName == 'Key') {
                    if(content.getText().contains('ToEGMS/To_be_Transmitted/')){
                        String filename = content.getText().substringAfter('ToEGMS/To_be_Transmitted/');
                        if(filename.length()>=1){
                            fileNames.add(filename);
                            IntegrationHeader__c intHeader = new IntegrationHeader__c(Status__c = 'New', Direction__c = 'To EGMS', Filename__c = filename);
                            insertList.add(intHeader);
                        }
                        
                    }
                    
                }
            }
            
        }
        //insert insertList;
        return fileNames;
    }
    
   
    /* public static void saveAsAttachment(Id recordId, String xmlString) {
       
            if (String.isNotEmpty(xmlString)) {
                Attachment attachment = new Attachment();
                attachment.ParentId = recordId; // Attach to the parent record (e.g., Payment Request)
                attachment.Name = 'PaymentRequest.xml';
                attachment.Body = Blob.valueOf(xmlString);
                attachment.ContentType = 'application/xml';
                insert attachment;
            } else {
                System.debug('Error: XML string is empty');
            }
        
    }*/



}