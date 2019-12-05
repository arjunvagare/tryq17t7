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
            string[] frequencyPattern = { "DAILY", "CUSTOM" };
            string currentFrequencyPattern = string.Empty;
            string timezone = "+05:30";
            try
            {
                MedScheduleUpdate medScheduleUpdate = null;
                for (int i = 0; i < frequencyPattern.Length; i++)
                {
                    currentFrequencyPattern = frequencyPattern[i];
                    medScheduleUpdate = new MedScheduleUpdate(currentFrequencyPattern, timezone, log);
                    medScheduleUpdate.Update();
                }
            }
            catch(Exception e)
            {
                log.LogError($"Error in DailyAndCustomMedScheduleIndia (Frequency Pattern='{currentFrequencyPattern}'):");
                log.LogError(e.Message);
                log.LogError(e.StackTrace);
            }
        } 
    }
}
