using System;
using Microsoft.Extensions.Logging;
using System.Data.SqlClient;
using System.Data;



namespace Aashirvadam.BatchUpdates
{
    class TaskUpdate
    {
        private readonly string Frequency;
        private readonly string Timezone;
        private ILogger Log;
        public TaskUpdate(string Frequency, string Timezone, ILogger log)
        {
            this.Frequency = Frequency;
            this.Timezone = Timezone;
            this.Log = log;
        }
        public void Update()
        {
            string curConnString = String.Empty, connDB = String.Empty;
            SqlConnection con = null;
            SqlCommand cmd = null;
            //string[] connString = { "DBConnectionStringProd", "DBConnectionStringDev" };
            string[] connString = { "DBConnectionStringDev" };
            for (int i = 0; i < connString.Length; i++)
            {
                try
                {
                    connDB = connString[i];
                    curConnString = Environment.GetEnvironmentVariable(connDB);
                    con = new SqlConnection(curConnString);
                    cmd = new SqlCommand("dbo.RefreshParentTaskUpdate", con)
                    {
                        CommandType = CommandType.StoredProcedure
                    };
                    cmd.Parameters.AddWithValue("@TimeZone", Timezone);
                    cmd.Parameters.Add("@DateToday", SqlDbType.Date);
                    cmd.Parameters["@DateToday"].Value = DateTime.Now;
                    cmd.Parameters.AddWithValue("@Frequency", Frequency);
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
                        Log.LogError($"Time: {DateTime.Now}  Timezone: {Timezone}  Frequency: {Frequency}");
                        Log.LogError(cmd.Parameters["@errMessage"].Value.ToString());
                    }
                }
                catch (Exception e)
                {
                    Log.LogError($"Error in TaskUpdate.update(): Frequency: {Frequency} Timezone: {Timezone} DB: {connDB}");
                    Log.LogError(e.Message);
                    Log.LogError(e.StackTrace);
                }
                finally
                {
                    if (cmd != null)
                    {
                        cmd.Dispose();
                    }

                    if (con != null)
                    {
                        if (con.State != ConnectionState.Closed)
                        {
                            con.Close();
                        }
                        con.Dispose();
                    }
                }
            }
        }
    }
}
