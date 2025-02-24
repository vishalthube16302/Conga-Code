public class AWS_Utility {

    public static void sendEmail(String subject, List<SObject> allHeaders, BatchNotificationDetails notifyDetails) {
        String body = '';  // Initialize an empty string
        
        body += notifyDetails.processingLog + '\n\n';
        body += '    Batch Processing Details:\n';
        body += '        Total Records Processed:   ' + notifyDetails.totalRecords + '\n';
        body += '        Successfully Processed:    ' + notifyDetails.totalSuccessfulRecords + '\n';
        body += '        Failed:                    ' + notifyDetails.totalFailedRecords + '\n\n';
       

        if (notifyDetails.totalFailedRecords > 0) {
            body += 'Errors:\n';
            for (SObject obj : allHeaders) {
                if (obj.getSObjectType() == IntegrationHeader__c.SObjectType) {
                    IntegrationHeader__c header = (IntegrationHeader__c)obj;
                    if (header.Status__c == 'Failed' && String.isNotEmpty(header.Log__c)) {
                        body += 'File Name: ' + header.Filename__c + ' - Error: ' + header.Log__c + '\n\n\n';
                    }
                }
            }
        }
        body += 'Please do not reply to this system-generated email. If you have any questions or concerns, you may contact the System Administrator.\n\n';
        body += 'Thank you,\nThe EGMS Team';

        GNT__KeyValueStore__c setting = GNT__KeyValueStore__c.getValues('AWS_BatchMonitorConfig');
        String emailAddresses = setting.GNT__TextValue__c; 
        List<String> recipients = emailAddresses.split(';');
        
        //List<String> recipients = new List<String>{ UserInfo.getUserEmail() };

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (String recipient : recipients) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{recipient});
            email.setSubject(subject);
            email.setPlainTextBody(body);
            emails.add(email);
        }

        Messaging.sendEmail(emails);
      
    }

    public static String getErrorMessage(Exception e) {
        return 'Error: ' + e.getMessage() + '\n' + e.getStackTraceString();
    }

    public class BatchNotificationDetails {
        public Integer totalRecords;
        public Integer totalSuccessfulRecords;
        public Integer totalFailedRecords;
        public String processingLog;

        // Constructor to initialize the default values
        public BatchNotificationDetails() {
            totalRecords = 0;
            totalSuccessfulRecords = 0;
            totalFailedRecords = 0;
            processingLog = '';
        }
    }
}