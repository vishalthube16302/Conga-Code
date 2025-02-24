/**
====================================================================================================

  File Name     :     AWS_MoveFileQueueable
  Created By    :     Vishal Thube
  Created Date  :     16-01-2025
  Purpose       :     This Queueable class handles the movement of files from S3 to EGMS by processing
                     a set of IntegrationHeader records

  CHANGE HISTORY: 
      Vishal Thube :   AWS_Utility Initial implementation notifying users if there were any failures during the file move process.

 
====================================================================================================
*/

public class AWS_MoveFileQueueable implements Queueable,Database.AllowsCallouts {
    private Set<Id> integrationHeaderIds;

    public AWS_MoveFileQueueable (Set<Id> integrationHeaderIds) {
        this.integrationHeaderIds = integrationHeaderIds;
    }

    public void execute(QueueableContext context) {
        if (!integrationHeaderIds.isEmpty()) {
            AWS_Utility.BatchNotificationDetails notifyDetails = new AWS_Utility.BatchNotificationDetails();
            notifyDetails.totalRecords = integrationHeaderIds.size();
            List<IntegrationHeader__c> allHeaders = [SELECT Id, Status__c, Filename__c, Log__c
                                                     FROM IntegrationHeader__c
                                                     WHERE Id IN :integrationHeaderIds];
            Boolean moveFileFailed = false;
            system.debug('allHeaders -->'+allHeaders );
            for (IntegrationHeader__c header : allHeaders) {
                try {
                    Boolean success = AWS_FileUploadDownloadCalloutCtrl.moveFile(header.Id, header.Filename__c, 'ToEGMS/To_be_Transmitted', 'ToEGMS/Transmitted');
                    if (success) {
                        header.Status__c = 'Completed';
                        notifyDetails.totalSuccessfulRecords++;
                    } else {
                        header.Status__c = 'Failed';
                        moveFileFailed = true;
                        notifyDetails.totalFailedRecords++;
                    }
                } catch (Exception e) {
                    header.Status__c = 'Failed';
                    header.Log__c = AWS_Utility.getErrorMessage(e);
                    notifyDetails.totalFailedRecords++;
                }
            }

            if (moveFileFailed) {
                notifyDetails.processingLog = 'The file download batch job ran successfully, but encountered errors while moving files.';
                 AWS_Utility.sendEmail('File Download Batch Job Status - From S3 Server to EGMS', allHeaders, notifyDetails);
            }

           
        }
    }
}