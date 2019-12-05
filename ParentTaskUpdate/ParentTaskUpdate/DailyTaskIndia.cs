using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace Aashirvadam.BatchUpdates
{
    public static class DailyTaskIndia
    {
        [FunctionName("DailyTaskIndia")]
        public static void Run([TimerTrigger("0 0 1 * * *")]TimerInfo myTimer, ILogger log)
        // Website_Time_Zone is set to India Standard Time
        {
            string frequency = "DAILY";
            string timezone = "+05:30";
            try
            {
                TaskUpdate taskUpdate = new TaskUpdate(frequency, timezone, log);
                taskUpdate.Update();
            }
            catch(Exception e)
            {
                log.LogError("Error in DailyTaskIndia: ");
                log.LogError(e.Message);
                log.LogError(e.StackTrace);
            }
        } 
    }
}
