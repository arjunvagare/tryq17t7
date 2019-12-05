using System;
using Microsoft.Extensions.Logging;
using System.Data.SqlClient;
using System.Data;



namespace Aashirvadam.BatchUpdates
{
    class MedScheduleUpdate
    {
        private readonly string FrequencyPattern;
        private readonly string Timezone;
        private ILogger Log;
        public MedScheduleUpdate(string FrequencyPattern, string Timezone, ILogger log)
        {
            this.FrequencyPattern = FrequencyPattern;
            this.Timezone = Timezone;
            this.Log = log;
        }
        public void Update()
        {
            string curConnStringVariable = String.Empty;
            SqlConnection con = null;
            SqlCommand cmd = null;
            string[] connStringVariable = { "DBConnectionStringProd", "DBConnectionStringDev" };
            for (int i = 0; i < connStringVariable.Length; i++)
            {
                try
                {
                    curConnStringVariable = connStringVariable[i];
                    con = new SqlConnection(Environment.GetEnvironmentVariable(curConnStringVariable));
                    cmd = new SqlCommand("dbo.RefreshMedScheduleUpdate", con);
                    //using (SqlConnection con = new SqlConnection(curConnString))
                    //using (SqlCommand cmd = new SqlCommand("dbo.RefreshMedScheduleUpdate", con))
                    //{
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.AddWithValue("@TimeZone", Timezone);
                    cmd.Parameters.Add("@DateToday", SqlDbType.Date);
                    cmd.Parameters["@DateToday"].Value = DateTime.Now;
                    cmd.Parameters.AddWithValue("@FrequencyPattern", FrequencyPattern);
                    cmd.Parameters.Add("@errFlag", SqlDbType.Bit);
                    cmd.Parameters.Add("@errMessage", SqlDbType.NVarChar, 4000);
                    cmd.Parameters["@errFlag"].Direction = ParameterDirection.Output;
                    cmd.Parameters["@errMessage"].Direction = ParameterDirection.Output;
                    con.Open();
                    cmd.ExecuteNonQuery();
                    con.Close();
                    if (((bool)cmd.Parameters["@errFlag"].Value))
                    {
                        Log.LogError("Error from stored procedure execution: ");
                        Log.LogError($"Time: {DateTime.Now}  Timezone: {Timezone}  FrequencyPattern: {FrequencyPattern}");
                        Log.LogError(cmd.Parameters["@errMessage"].Value.ToString());
                    }
                    //  }
                }
                catch (Exception e)
                {
                    Log.LogError($"Error in TaskUpdate.update(): FrequencyPattern: {FrequencyPattern} Timezone: {Timezone} DB: {curConnStringVariable}");
                    Log.LogError(e.Message);
                    Log.LogError(e.StackTrace);
                }
                finally
                {
                    if (cmd != null)
                        cmd.Dispose();
                    if (con != null)
                        con.Dispose();
                }
            }
        }
    }
}
