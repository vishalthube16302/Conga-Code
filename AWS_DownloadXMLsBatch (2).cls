/**
====================================================================================================

  File Name     :     AWS_DownloadXMLsBatch
  Created By    :     Vishal Thube
  Created Date  :     16-01-2025
  Purpose       :     This method handles the deletion of a file from AWS S3 storage via HTTP callouts.            
  
  CHANGE HISTORY: 
      Vishal Thube :   Implement AWS_Utility to Send Email Notification.

======================================================================================================
 */

global class AWS_DownloadXMLsBatch extends GNT.BatchApexHandler implements Database.Stateful {
    
    global AWS_Utility.BatchNotificationDetails notifyDetails = new AWS_Utility.BatchNotificationDetails();
    global Set<Id> integrationHeaderIds = new Set<Id>();
    global List<IntegrationHeader__c> allHeaders = new List<IntegrationHeader__c>();
    Boolean batchFailed = false;
    Id integrationHeaderId ;
    List<Attachment > attachmentList = new List<Attachment >();



    global AWS_DownloadXMLsBatch() {
        
        AWS_FileUploadDownloadCalloutCtrl.fetchS3fileNames();
    }

    global AWS_DownloadXMLsBatch(Id integrationHeaderId) {
        this.integrationHeaderId = integrationHeaderId;
    }
    
    

    global override String getQuery() {
       
        String query ;
        if (integrationHeaderId != null) {
            query = 'SELECT Id, Status__c, Filename__c, Log__c FROM IntegrationHeader__c WHERE Id = \'' +integrationHeaderId + '\'';
        }else{
            query = 'SELECT Id, Status__c, Filename__c,Log__c  FROM IntegrationHeader__c WHERE Status__c = \'New\' AND Direction__c = \'To EGMS\' ';
        }
       
        return query;
        
    }

    
    
    global override void execute(List<SObject> scope) {
    //System.assertEquals('2', JSON.serialize(integrationHeaderIds));
        List<IntegrationHeader__c> headers = (List<IntegrationHeader__c>) scope;
        if(!integrationHeaderIds.isEmpty())    integrationHeaderIds.clear();
        
        try {
            notifyDetails.totalRecords += headers.size();
            List<IntegrationHeader__c> toUpdate = new List<IntegrationHeader__c>();
            
            for (IntegrationHeader__c header : headers) {
                try {
                    Map<String,object> responseMap = AWS_FileUploadDownloadCalloutCtrl.downloadFile (header.Filename__c, 'ToEGMS/To_be_Transmitted');
                     
                    if (responseMap.ContainsKey('isSuccess') && (Boolean) responseMap.get('isSuccess') == true && responseMap.ContainsKey('fileResponse') ) {
                        String fileResponse = (String) responseMap.get('fileResponse');
                        saveAsAttachment(header, fileResponse  );                        
                        header.Status__c = 'Ready for Processing';
                        notifyDetails.totalSuccessfulRecords++;
                        integrationHeaderIds.add(header.Id);
                    } else if(responseMap.ContainsKey('isSuccess') && responseMap.get('isSuccess') == false){
                        header.Status__c = 'Failed';
                        
                        header.Log__c = (String) responseMap.get('ErrorMessage');
                        notifyDetails.totalFailedRecords++;
                    }

                } catch (Exception e) {
                    header.Status__c = 'Failed';
                    header.Log__c = AWS_Utility.getErrorMessage(e);
                    notifyDetails.totalFailedRecords++;
                }
                toUpdate.add(header);
                
                
            }
            If(!attachmentList.isEmpty()){
                insert attachmentList;
            }
            if (!toUpdate.isEmpty()) {
                update toUpdate;
                allHeaders.addAll(toUpdate);
                
            }
        } catch (Exception e) {
            this.batchFailed = true;
            String errorMessage = AWS_Utility.getErrorMessage(e);

            for (IntegrationHeader__c iHeader : headers) {
                if (iHeader.Status__c != 'Ready for Processing') {
                    iHeader.Status__c = 'Failed';
                    iHeader.Log__c = errorMessage;
                    notifyDetails.totalFailedRecords++;
                }
            }
            if (!headers.isEmpty()) {
                update headers;
                allHeaders.addAll(headers);
            }

            notifyDetails.processingLog = 'The file download batch job from the S3 server to EGMS has failed.' + errorMessage;
            AWS_Utility.sendEmail('File Download Batch Job Status - From S3 Server to EGMS', allHeaders, notifyDetails);
        }
    }
   global override void finish() {
        if (notifyDetails.totalRecords == 0) {
            notifyDetails.totalSuccessfulRecords = 0;
            notifyDetails.totalFailedRecords = 0;
        }
        
        if (!this.batchFailed) {
            if (!integrationHeaderIds.isEmpty()) {
                 System.enqueueJob(new AWS_MoveFileQueueable(integrationHeaderIds));
            }
            notifyDetails.processingLog = 'The file download batch job from the S3 server to DCRA Grant has run successfully.';
            AWS_Utility.sendEmail('File Download Batch Job Status - From S3 Server to DCRA Grant', allHeaders, notifyDetails);
        }
    }
   
    @future 
    global static void moveFileCallInFuture(Set<Id> integrationHeaderIds) {
        if(!integrationHeaderIds.isEmpty()){
            AWS_Utility.BatchNotificationDetails notifyDetails = new AWS_Utility.BatchNotificationDetails();
            Boolean moveFileFailed = false;
            notifyDetails.totalRecords = integrationHeaderIds.size();    
            List<IntegrationHeader__c> allHeaders = [SELECT Id, Status__c, Filename__c, Log__c  FROM IntegrationHeader__c
                                                   WHERE Id IN :integrationHeaderIds];
    
            for (IntegrationHeader__c header : allHeaders) {
                
                try {
                    Boolean success = AWS_FileUploadDownloadCalloutCtrl.moveFile(header.Id,header.Filename__c,'ToEGMS/To_be_Transmitted','ToEGMS/Transmitted');
    
                    if (success) {
                        header.Status__c = 'Completed';
                        notifyDetails.totalSuccessfulRecords++;
                    } else {
                        header.Status__c = 'Failed';
                        moveFileFailed = true;
                        notifyDetails.totalFailedRecords++;
                    }
                }catch (Exception e) {
                    header.Status__c = 'Failed';
                    header.Log__c = AWS_Utility.getErrorMessage(e);
                    notifyDetails.totalFailedRecords++;
                }
            }
    
            if (moveFileFailed) {
                notifyDetails.processingLog = 'The file download batch job from the S3 server to DCRA Grant has run successfully, but encountered errors while moving files.';
                AWS_Utility.sendEmail('File Download Batch Job Status - From S3 Server to DCRA Grant',allHeaders,notifyDetails);
            }
        }
    }
    /*//Update Code with latest ContectVersion file structure 
    global void saveAsAttachment (IntegrationHeader__c header, String xmlString) {
        if (String.isNotEmpty(xmlString)) {
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = header.Filename__c;
            contentVersion.PathOnClient = '/' + header.Filename__c;
            contentVersion.VersionData = Blob.valueOf(xmlString);
            contentVersion.IsMajorVersion = true;
            insert contentVersion;
    
           ContentVersion insertedVersion = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];

    
            ContentDocumentLink contentLink = new ContentDocumentLink();
            contentLink.ContentDocumentId = insertedVersion.ContentDocumentId ;
            contentLink.LinkedEntityId = header.Id;
            contentLink.ShareType = 'V';
            contentLink.Visibility = 'AllUsers';
            insert contentLink;
        }
    }*/



   global void saveAsAttachment(IntegrationHeader__c header, String xmlString) {
        
            if (String.isNotEmpty(xmlString)) {
                Attachment attachment = new Attachment();
                    attachment.ParentId = header.Id; // Attach to the parent record (e.g., Payment Request)
                    attachment.Name = header.Filename__c;
                    attachment.Body = Blob.valueOf(xmlString);
                    attachment.ContentType = 'application/xml';
                attachmentList.add(attachment);
            } else {
                System.debug('Error: XML string is empty');
            }
       
    }
}