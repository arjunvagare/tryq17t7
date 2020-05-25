using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace Aashirvadam.BatchUpdates
{
    public static class DailyAndCustomMedScheduleIndia
    {
        [FunctionName("DailyAndCustomMedScheduleIndia")]
        public static void Run([TimerTrigger("0 10 1 * * *")]TimerInfo myTimer, ILogger log)
        // Website_Time_Zone is set to India Standard Time
        {
            string[] frequency = { "DAILY", "CUSTOM" };
            string currentFrequency = string.Empty;
            string timezone = "+05:30";
            try
            {
                MedScheduleUpdate medScheduleUpdate = null;
                for (int i = 0; i < frequency.Length; i++)
                {
                    currentFrequency = frequency[i];
                    medScheduleUpdate = new MedScheduleUpdate(currentFrequency, timezone, log);
                    medScheduleUpdate.Update();
                }
            }
            catch(Exception e)
            {
                log.LogError($"Error in DailyAndCustomMedScheduleIndia (Frequency='{currentFrequency}'):");
                log.LogError(e.Message);
                log.LogError(e.StackTrace);
            }
        } 
    }
}
