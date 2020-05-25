using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;


namespace Aashirvadam.BatchUpdates
{
    public static class MonthlyMedScheduleIndia
    {
        [FunctionName("MonthlyMedScheduleIndia")]
        public static void Run([TimerTrigger("0 10 2 1 * *")]TimerInfo myTimer, ILogger log)
        // Website_Time_Zone is set to India Standard Time
        {
            string frequency = "MONTHLY";
            string timezone = "+05:30";
            try
            {
                MedScheduleUpdate medScheduleUpdate = new MedScheduleUpdate(frequency, timezone, log);
                medScheduleUpdate.Update();
            }
            catch(Exception e)
            {
                log.LogError("Error in MonthlyMedScheduleIndia: ");
                log.LogError(e.Message);
                log.LogError(e.StackTrace);
            }
        } 
    }
}
