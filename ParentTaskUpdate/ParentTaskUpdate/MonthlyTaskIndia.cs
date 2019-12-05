using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;


namespace Aashirvadam.BatchUpdates
{
    public static class MonthlyTaskIndia
    {
        [FunctionName("MonthlyTaskIndia")]
        public static void Run([TimerTrigger("0 0 2 1 * *")]TimerInfo myTimer, ILogger log)
        // Website_Time_Zone is set to India Standard Time
        {
            string frequency = "MONTHLY";
            string timezone = "+05:30";
            try
            {
                TaskUpdate taskUpdate = new TaskUpdate(frequency, timezone, log);
                taskUpdate.Update();
            }
            catch(Exception e)
            {
                log.LogError("Error in MonthlyTaskIndia: ");
                log.LogError(e.Message);
                log.LogError(e.StackTrace);
            }
        } 
    }
}
