# Description:
#   An HTTP Listener for notifications on github pushes
#
# Dependencies:
#   "url": ""
#   "querystring": ""
#   "gitio2": "2.0.0"
#
# Configuration:
#   Just put this url <HUBOT_URL>:<PORT>/hubot/gh-commits?room=<room> into you'r github hooks
#   HUBOT_GITHUB_COMMITS_ONLY -- Only report pushes with commits. Ignores creation of tags and branches.
#
# Commands:
#   None
#
# URLS:
#   POST /hubot/gh-commits?room=<room>[&type=<type]
#
# Authors:
#   nesQuick

fs = require('fs');
url = require('url')
querystring = require('querystring')
gitio = require('gitio2')
sys = require('sys')
exec = require('child_process').exec

puts = (error, stdout, stderr) ->
  sys.puts stdout
  return

module.exports = (robot) ->

  robot.router.post "/hubot/gh-commits", (req, res) ->
    query = querystring.parse(url.parse(req.url).query)

    res.send 200

    user = {}
    user.room = query.room if query.room
    user.type = query.type if query.type
        
    robot.messageRoom user.room, "Received #{req.body}"

#    return if req.body.zen? # initial ping
    push = req.body
    
    try
      if push.commits.length > 0
        commitWord = if push.commits.length > 1 then "commits" else "commit"
        robot.send user, "Got #{push.commits.length} new #{commitWord} from #{push.commits[0].author.name} on #{push.repository.name}"
        robot.send user, "Building yo shit #{push.commits[0].author.name}"
        
        # for ease domain and repo are the same
        repo = push.repository.name
        
        #check if main directory already exists
        # at /var/www/html/domain
        if !fs.existsSync('/var/www/html/#{repo}')
            #if they don't exist create the directories
            #TODO fix file path to domain
            exec 'sudo mkdir -p /var/www/html/#{repo}', puts
            exec 'sudo mkdir -p /var/www/html/#{repo}/{public_html,logs,repo}', puts
        
        #check if configuration already exists 
        # at /etc/apache2/sites-available/domain.conf
        if !fs.existsSync('/etc/apache2/sites-available/#{repo}.conf') 
            # if it doesn't exist create configuration for virtual host
            virtualHost = "<Directory /var/www/html/#{repo}/public_html>\n
        Require all granted\n
</Directory>\n
\n
<VirtualHost *:80>\n
        ServerName #{repo}\n
        ServerAlias www.#{repo}\n
        ServerAdmin webmaster@localhost\n
        DocumentRoot /var/www/html/#{repo}/public_html\n
        \n
        #LogLevel info ssl:warn
        \n
        ErrorLog /var/www/html/#{repo}/logs/error.log\n
        CustomLog /var/www/html/#{repo}/logs/access.log combined\n
</VirtualHost>\n"
        
            #Enable the config
            #sudo a2ensite domain.conf
            exec 'sudo a2ensite #{repo}.conf', puts

            #restart apache
            #sudo systemctl reload apache2
            exec 'sudo systemctl reload apache2', puts

            #setup ssl
            #sudo letsencrypt --apache -d domain --agree-tos --non-interactive --email jonathonshields@gmail.com --redirect
            exec 'sudo letsencrypt --apache -d #{repo} --agree-tos --non-interactive --email jonathonshields@gmail.com --redirect', puts
            
            #TODO fix file path to domain
            fs.writeFile "/etc/apache2/sites-available/#{repo}.conf", virtualHost, (err) ->
                return console.log(err) if err
                console.log "The file was saved!" 
        
        #Get latest git
        exec 'cd /var/www/html/#{repo}/repo', puts
        if !fs.existsSync('/var/www/html/#{repo}/repo/#{repo}')
            exec 'git clone #{push.repository.clone_url}', puts
        exec 'cd /var/www/html/#{repo}/repo/#{repo}', puts
        exec 'git pull', puts
        
        #jekyll build & deploy
        
    catch error
      console.log "github-commits error: #{error}. Push: #{JSON.stringify push}"
