String jobName = 'GGT-05 Trip Status Daily';
String cronExp = '0 0 3 * * ?';

String jobId = System.schedule(jobName, cronExp, new TripStatusScheduler());
System.debug('Job planifié : ' + jobName + ' (Id = ' + jobId + ', cron = ' + cronExp + ')');
