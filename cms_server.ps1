# PowerShell Web Server for CMS
# Listens on http://localhost:8080/

$port = 8080
$root = Get-Location
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")

try {
    $listener.Start()
} catch {
    Write-Host "Error starting listener. Port $port might be in use." -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit
}

Write-Host "CMS Server Running at http://localhost:$port/admin.html" -ForegroundColor Cyan
Write-Host "Do not close this window while editing." -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop."

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response
    
    $path = $request.Url.LocalPath
    $method = $request.HttpMethod

    # API Endpoint: Save Data
    if ($path -eq "/api/save" -and $method -eq "POST") {
        try {
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $content = $reader.ReadToEnd()
            $reader.Close()

            # Save to data.js
            $filePath = Join-Path $root "data.js"
            [System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::UTF8)

            Write-Host "[$([DateTime]::Now)] Saved data.js" -ForegroundColor Green
            
            $response.StatusCode = 200
            $response.StatusDescription = "OK"
            
            # CORS headers just in case
            $response.AddHeader("Access-Control-Allow-Origin", "*")
        } catch {
            Write-Host "Error saving file: $_" -ForegroundColor Red
            $response.StatusCode = 500
        }
    }
    else {
        # Serve Static Files
        if ($path -eq "/") { $path = "/index.html" }
        
        $localPath = Join-Path $root $path.TrimStart('/')
        
        if (Test-Path $localPath -PathType Leaf) {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($localPath)
                $response.ContentLength64 = $bytes.Length
                
                # Basic MIME types
                $ext = [System.IO.Path]::GetExtension($localPath).ToLower()
                switch ($ext) {
                    ".html" { $response.ContentType = "text/html" }
                    ".js"   { $response.ContentType = "application/javascript" }
                    ".css"  { $response.ContentType = "text/css" }
                    ".png"  { $response.ContentType = "image/png" }
                    ".jpg"  { $response.ContentType = "image/jpeg" }
                    ".svg"  { $response.ContentType = "image/svg+xml" }
                    Default { $response.ContentType = "application/octet-stream" }
                }
                
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } catch {
                $response.StatusCode = 500
            }
        } else {
            $response.StatusCode = 404
        }
    }

    $response.Close()
}