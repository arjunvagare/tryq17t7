using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;


namespace Aashirvadam.BatchUpdates
{
    public static class WeeklyMedScheduleIndia
    {
        [FunctionName("WeeklyMedScheduleIndia")]
        public static void Run([TimerTrigger("0 40 1 * * MON")]TimerInfo myTimer, ILogger log)
        // Website_Time_Zone is set to India Standard Time
        {
            string frequencyPattern = "WEEKLY";
            string timezone = "+05:30";
            try
            {
                MedScheduleUpdate medScheduleUpdate = new MedScheduleUpdate(frequencyPattern, timezone, log);
                medScheduleUpdate.Update();
            }
            catch(Exception e)
            {
                log.LogError("Error in WeeklyMedScheduleIndia: ");
                log.LogError(e.Message);
                log.LogError(e.StackTrace);
            }
        } 
    }
}
