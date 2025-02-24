/**
====================================================================================================

  File Name     :     AWS_UploadXMLsBatch
  Created By    :     Vishal Thube
  Created Date  :     16-01-2025
  Purpose       :     This Batch class handles the uploading of files from the EGMS system to the S3 server.
                     It processes a set of IntegrationHeader records, updating their statuses accordingly 
                     and sending email notifications based on the batch execution status.

  CHANGE HISTORY: 
     
====================================================================================================
*/

global class AWS_UploadXMLsBatch extends GNT.BatchApexHandler implements Database.Stateful {

    global Set<Id> integrationHeaderIds { get; set; }
    global AWS_Utility.BatchNotificationDetails notifyDetails = new AWS_Utility.BatchNotificationDetails();
    global List<IntegrationHeader__c> allHeaders = new List<IntegrationHeader__c>();
    Boolean batchFailed = false;

    global AWS_UploadXMLsBatch () {
        this.integrationHeaderIds = new Set<Id>();
    }

    global AWS_UploadXMLsBatch (Set<Id> integrationHeaderIds) {
        this.integrationHeaderIds = integrationHeaderIds;
    }

    global override String getQuery() {
        
        String query ;
        if (!integrationHeaderIds.isEmpty()) {
            query = 'SELECT Id, Status__c, Filename__c FROM IntegrationHeader__c WHERE Id IN :integrationHeaderIds';
        }else{
            query = 'SELECT Id, Status__c, Filename__c FROM IntegrationHeader__c WHERE Status__c = \'Ready for Processing\' AND Direction__c = \'From EGMS\'';
        }
        return query;
    }

    global override void execute(List<SObject> scope) {
        List<IntegrationHeader__c> headers = (List<IntegrationHeader__c>) scope;
        try {
            notifyDetails.totalRecords += headers.size();
            List<IntegrationHeader__c> toUpdate = new List<IntegrationHeader__c>();

            for (IntegrationHeader__c header : headers) {
                try {
                    Boolean success = AWS_FileUploadDownloadCalloutCtrl.uploadFile(header.Id, 'FromEGMS/To_be_Transmitted');

                    if (success) {
                        header.Status__c = 'Completed';
                        notifyDetails.totalSuccessfulRecords++;
                    } else {
                        header.Status__c = 'Failed';
                        notifyDetails.totalFailedRecords++;
                    }

                } catch (Exception e) {
                    header.Status__c = 'Failed';
                    header.Log__c = AWS_Utility.getErrorMessage(e);
                    notifyDetails.totalFailedRecords++;
                }
                toUpdate.add(header);
            }

            if (!toUpdate.isEmpty()) {
                update toUpdate;
                allHeaders.addAll(toUpdate);
            }

        } catch (Exception e) {
            this.batchFailed = true;
            String errorMessage = AWS_Utility.getErrorMessage(e);

            for (IntegrationHeader__c iHeader : headers) {
                if (iHeader.Status__c != 'Completed') {
                    iHeader.Status__c = 'Failed';
                    iHeader.Log__c = errorMessage;
                    notifyDetails.totalFailedRecords++;
                }
            }

            if (!headers.isEmpty()) {
                update headers;
                allHeaders.addAll(headers);
            }

            notifyDetails.processingLog = 'The file upload batch job from the DCRA Grant to S3 server has run failed. ' + errorMessage;
            AWS_Utility.sendEmail('File upload Batch Job Status - From the DCRA Grant to S3 server', allHeaders, notifyDetails);
        }
    }

    global override void finish() {
        if (notifyDetails.totalRecords == 0) {
            notifyDetails.totalRecords = 0;
            notifyDetails.totalSuccessfulRecords = 0;
            notifyDetails.totalFailedRecords = 0;
        }
        
        if (this.batchFailed == false) {
            notifyDetails.processingLog = 'The file upload batch job from the DCRA Grant to S3 server has run successfully.';
            AWS_Utility.sendEmail('File upload Batch Job Status - From the DCRA Grant to S3 server', allHeaders, notifyDetails);
        }
    }
}