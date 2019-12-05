using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;


namespace Aashirvadam.BatchUpdates
{
    public static class WeeklyTaskIndia
    {
        [FunctionName("WeeklyTaskIndia")]
        public static void Run([TimerTrigger("0 30 1 * * MON")]TimerInfo myTimer, ILogger log)
        // Website_Time_Zone is set to India Standard Time
        {
            string frequency = "WEEKLY";
            string timezone = "+05:30";
            try
            {
                TaskUpdate taskUpdate = new TaskUpdate(frequency, timezone, log);
                taskUpdate.Update();
            }
            catch(Exception e)
            {
                log.LogError("Error in WeeklyTaskIndia: ");
                log.LogError(e.Message);
                log.LogError(e.StackTrace);
            }
        } 
    }
}
