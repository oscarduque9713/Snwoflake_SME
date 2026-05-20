$Connection = "my_conn"
$BasePath = "C:\Users\GJX\Downloads\Notebooks_snowflake\SQL"

function Run-SnowSqlScript {
    param (
        [string]$StepName,
        [string]$ScriptName,
        [string]$BatchId = ""
    )

    $FilePath = Join-Path -Path $BasePath -ChildPath $ScriptName

    Write-Host $StepName
    Write-Host "Archivo SQL: $FilePath"

    if (-not (Test-Path $FilePath)) {
        Write-Host "ERROR: No existe el archivo: $FilePath"
        exit 1
    }

    if ((Get-Item $FilePath).PSIsContainer) {
        Write-Host "ERROR: La ruta apunta a una carpeta, no a un archivo: $FilePath"
        exit 1
    }

    if ($BatchId -ne "") {
        Write-Host "Usando Batch ID: $BatchId"

        snowsql -c $Connection `
            -o exit_on_error=True `
            -o variable_substitution=True `
            -D BATCH_ID="$BatchId" `
            -f "$FilePath"
    }
    else {
        snowsql -c $Connection `
            -o exit_on_error=True `
            -f "$FilePath"
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Fallo el script $FilePath"
        exit 1
    }
}

Run-SnowSqlScript -StepName "1. Ejecutando preparacion de ambiente..." -ScriptName "0.Prep_Env.sql"

Run-SnowSqlScript -StepName "1.1 Creando batch en Snowflake..." -ScriptName "0.1.Start_Batch.sql"

$BatchId = snowsql -c $Connection `
    -o output_format=plain `
    -o header=false `
    -o timing=false `
    -o friendly=false `
    -q "SELECT BATCH_ID FROM PROJECT_SEMESTRUCTURED.BRONZE.PIPELINE_BATCH_CONTROL WHERE STATUS = 'RUNNING' ORDER BY START_TS DESC LIMIT 1;"

$BatchId = $BatchId.Trim()

Write-Host "Batch ID desde Snowflake: $BatchId"

Run-SnowSqlScript -StepName "2. Subiendo archivos al stage..." -ScriptName "1.Load_files_stage.sql" -BatchId $BatchId

Run-SnowSqlScript -StepName "3. Ejecutando ingesta..." -ScriptName "2.Ingest.sql" -BatchId $BatchId

Run-SnowSqlScript -StepName "3.1 Actualizando conteos batch..." -ScriptName "2.1.Validate_Ingest.sql" -BatchId $BatchId

Run-SnowSqlScript -StepName "3.2 Validando registros cargados..." -ScriptName "2.2.Validate_Batch_Load.sql" -BatchId $BatchId

Run-SnowSqlScript -StepName "4. Ejecutando transformacion..." -ScriptName "3.Transform.sql" $BatchId

Run-SnowSqlScript -StepName "5. Ejecutando business rules..." -ScriptName "4.Business_rules_enrich_information.sql" $BatchId

Run-SnowSqlScript -StepName "6. Ejecutando Gold..." -ScriptName "5.Load_Gold.sql" $BatchId

Run-SnowSqlScript -StepName "7. Ejecutando Validacion succesfull register control..." -ScriptName "6.End_Batch_Success.sql" $BatchId

Write-Host "Pipeline Ejecutado correctamente hasta validacion de ingesta."
Write-Host "Batch ID: $BatchId"