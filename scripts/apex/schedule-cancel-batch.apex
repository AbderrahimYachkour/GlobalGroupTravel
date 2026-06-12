String jobName = 'GGT-04 Trip Cancel Daily';
String cronExp = '0 0 2 * * ?';

String jobId = System.schedule(jobName, cronExp, new TripCancelScheduler());
System.debug('Job planifié : ' + jobName + ' (Id = ' + jobId + ', cron = ' + cronExp + ')');
