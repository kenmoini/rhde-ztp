//const express = require('express');
const http = require('http');
const fs = require('fs');
const path = require('path');
const qs = require('querystring');

const port = process.env.PORT || 6969;
const ansibleControllerHost = process.env.ANSIBLE_CONTROLLER_HOST || 'http://ansible-controller:8080';
//const server = http.createServer(express);

//server.listen(port, function() {
    //console.log(`Server is listening on ${port}!`)
//});

http.createServer(function(request, response){
    // Set CORS headers
    response.setHeader('Access-Control-Allow-Origin', '*');
    response.setHeader('Access-Control-Request-Method', '*');
    response.setHeader('Access-Control-Allow-Methods', 'OPTIONS, GET');
    response.setHeader('Access-Control-Allow-Headers', '*');
    if ( request.method === 'OPTIONS' ) {
      response.writeHead(200);
      response.end();
      return;
    }

    var filePath =  '.' + request.url;
    if (filePath == './')
        filePath = './index.html';

    var extname = path.extname(filePath);
    var contentType = 'text/html';

    switch (extname) {
      case '.js':
          contentType = 'text/javascript';
          break;
      case '.css':
          contentType = 'text/css';
          break;
      case '.json':
          contentType = 'application/json';
          break;
      case '.png':
          contentType = 'image/png';
          break;      
      case '.jpg':
          contentType = 'image/jpg';
          break;
      case '.wav':
          contentType = 'audio/wav';
          break;
    }


  if (request.url.startsWith('/api')) {

    // Process POST messages
    if (request.method === 'POST') {
      if (request.url === '/api/sendToAnsible') {
        let body = '';
        request.on('data', chunk => {
            body += chunk.toString(); // convert Buffer to string
        });
        request.on('end', () => {
          pdata = qs.parse(body);
          // Assemble JSON object
          var msgData = {"ocrText": pdata.ocrText, "jobCode": pdata.jobCode};

          // Send the message to Ansible Controller
          console.log(JSON.stringify(msgData));
          request.post(
            ansibleControllerHost,
            { json: JSON.stringify(msgData) },
            function (error, response, body) {
              if (!error && response.statusCode == 200) {
                console.log(body);
              }
            }
          );
          response.end('ok');
        });
      }
    }
  } else if (request.url === '/healthz' && request.method === 'GET') {
    // Kubernetes health check
    response.writeHead(200, {'Content-Type': 'text/html'});
    response.end('ok');
  } else {
    fs.readFile(filePath, function(error, content) {
      if (error) {
          if(error.code == 'ENOENT'){
              fs.readFile('./404.html', function(error, content) {
                  console.log("404 error: " + filePath);
                  response.writeHead(404, { 'Content-Type': contentType });
                  response.end(content, 'utf-8');
              });
          }
          else {
              console.log("500 error")
              response.writeHead(500);
              response.end('Sorry, check with the site admin for error: '+error.code+' ..\n');
              //response.end();
          }
      }
      else {
          response.writeHead(200, { 'Content-Type': contentType });
          response.end(content, 'utf-8');
      }
    });
  }
}).listen(port, function() {
  console.log(`Server is listening on ` + port + `!`)
});

