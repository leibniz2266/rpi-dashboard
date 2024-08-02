#!/bin/bash


# Set up the weather and calendar widgets for the 

YOUR_API_KEY = 'paste your key here'
YOUR_CITY_ID = 'paste your city id here'
YOUR_CALENDAR_LINK = 'your link. it should be an .ics link, not an .html link'


# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y git xorg lightdm openbox obconf xserver-xorg-video-fbdev htop lxappearance lxterminal feh neofetch midori mousepad

# Install desktop packages (if you want to use desktop functionality via VNC for example)
 sudo apt install -y lxtask tint2 pcmanfm dillo netsurf-gtk abiword gnumeric
# Enable VNC

sudo raspi-config nonint do_vnc 0

# Create directories for themes
mkdir -p ~/.themes

# Download and install themes
mkdir -p ~/tmp
cd ~/tmp

git clone https://github.com/addy-dclxvi/gtk-theme-collections ~/.themes
git clone https://github.com/logico/typewriter-gtk
mv typewriter-gtk/* ~/.themes
git clone https://github.com/addy-dclxvi/openbox-theme-collections
mv openbox-theme-collections/* ~/.themes
git clone https://github.com/catppuccin/openbox
mv openbox/themes/* ~/.themes
rm -rf ~/.themes/.git *.jpg

cd
rm -rf ~/tmp

# Enable lightdm
sudo systemctl enable lightdm


# Set boot behavior to desktop
sudo raspi-config nonint do_boot_behaviour B4

# Configure swap
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# Boot partition edits. These will help with HDMI output on the Pi 4, and will enable ethernet gadget mode for the Pi Zero series
sudo bash -c 'echo "[pi4]" >> /boot/firmware/config.txt'
sudo bash -c 'echo "hdmi_force_hotplug=1" >> /boot/firmware/config.txt'
sudo bash -c 'echo "hdmi_group=2" >> /boot/firmware/config.txt'
sudo bash -c 'echo "hdmi_mode=82" >> /boot/firmware/config.txt'
sudo bash -c 'echo "[all]" >> /boot/firmware/config.txt'
sudo bash -c 'echo "dtoverlay=dwc2" >> /boot/firmware/config.txt'

echo "neofetch" >> /home/rpi/.bashrc

# Add modules-load to /boot/firmware/cmdline.txt after rootwait
sudo sed -i 's/\(rootwait\)/\1 modules-load=dwc2,g_ether/' /boot/firmware/cmdline.txt

# Restart lightdm to ensure it's running correctly
sudo systemctl restart lightdm

# Install Ruby and dependencies for Smashing
sudo apt install -y ruby-full build-essential zlib1g-dev

# Set up RubyGems environment
echo '# Install Ruby Gems to ~/.gems' >> ~/.bashrc
echo 'export GEM_HOME="$HOME/.gems"' >> ~/.bashrc
echo 'export PATH="$HOME/.gems/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install Bundler
sudo gem install bundler

# Install Smashing
sudo gem install smashing

# Create a new Smashing project
smashing new my_dashboard
cd my_dashboard

# Install project dependencies
bundle install

# Create weather widget
mkdir widgets/weather
cat <<EOL > widgets/weather/weather.html
<div data-id="weather" data-view="WeatherWidget" class="weather-widget">
  <h2>Weather</h2>
  <div class="weather-info">
    <span class="temperature">{{temperature}}°C</span>
    <span class="description">{{description}}</span>
  </div>
</div>
EOL

cat <<EOL > widgets/weather/weather.coffee
class Dashing.WeatherWidget extends Dashing.Widget
  @accessor 'temperature', ->
    @get('temperature') || 'N/A'

  @accessor 'description', ->
    @get('description') || 'No data'

  ready: ->
    @onData @scope(), (data) =>
      @scope().temperature = data.temperature
      @scope().description = data.description
EOL

cat <<EOL > widgets/weather/weather.scss
.weather-widget {
  text-align: center;
  .weather-info {
    font-size: 2em;
  }
}
EOL

# Create calendar widget
mkdir widgets/calendar
cat <<EOL > widgets/calendar/calendar.html
<div data-id="calendar" data-view="CalendarWidget" class="calendar-widget">
  <h2>Calendar</h2>
  <ul class="events">
    {{#each events}}
      <li>
        <span class="event-time">{{time}}</span>
        <span class="event-title">{{title}}</span>
      </li>
    {{/each}}
  </ul>
</div>
EOL

cat <<EOL > widgets/calendar/calendar.coffee
class Dashing.CalendarWidget extends Dashing.Widget
  @accessor 'events', []

  ready: ->
    @onData @scope(), (data) =>
      @scope().events = data.events
EOL

cat <<EOL > widgets/calendar/calendar.scss
.calendar-widget {
  .events {
    list-style-type: none;
    padding: 0;
    li {
      margin: 5px 0;
    }
    .event-time {
      font-weight: bold;
    }
    .event-title {
      margin-left: 10px;
    }
  }
}
EOL

# Create weather job
cat <<EOL > jobs/weather.rb
require 'net/http'
require 'json'

SCHEDULER.every '10m', :first_in => 0 do |job|
  api_key = $YOUR_API_KEY
  city_id = $YOUR_CITY_ID
  units = 'imperial' # Use 'imperial' for Fahrenheit

  http = Net::HTTP.new('api.openweathermap.org', 80)
  response = http.request(Net::HTTP::Get.new("/data/2.5/weather?id=#{city_id}&units=#{units}&appid=#{api_key}"))

  weather_data = JSON.parse(response.body)

  temperature = weather_data['main']['temp']
  description = weather_data['weather'][0]['description']

  send_event('weather', { temperature: temperature, description: description })
end
EOL

# Create calendar job
cat <<EOL > jobs/calendar.rb
require 'net/http'
require 'json'
require 'icalendar'

SCHEDULER.every '30m', :first_in => 0 do |job|
  ical_url = $YOUR_CALENDAR_LINK
  uri = URI(ical_url)
  response = Net::HTTP.get(uri)
  calendars = Icalendar::Calendar.parse(response)
  events = calendars.first.events.map do |event|
    {
      title: event.summary,
      time: event.dtstart.strftime('%I:%M %p')
    }
  end

  send_event('calendar', { events: events })
end
EOL

# Edit the sample dashboard layout to include the new widgets
cat <<EOL > dashboards/sample.erb
<div class="gridster">
  <ul>
    <li data-row="1" data-col="1" data-sizex="2" data-sizey="1">
      <div data-id="weather" data-view="WeatherWidget"></div>
    </li>
    <li data-row="2" data-col="1" data-sizex="2" data-sizey="2">
      <div data-id="calendar" data-view="CalendarWidget"></div>
    </li>
  </ul>
</div>
EOL

# Set up Openbox autostart for kiosk mode with Midori
mkdir -p ~/.config/openbox
cat <<EOL > ~/.config/openbox/autostart
# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Launch Smashing dashboard in kiosk mode using Midori
midori -e Fullscreen -a http://localhost:3030 &
EOL

# Create systemd service to start Smashing on boot
cat <<EOL | sudo tee /etc/systemd/system/smashing.service
[Unit]
Description=Smashing Dashboard
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/rpi/my_dashboard
ExecStart=/usr/local/bin/smashing start
Restart=always
User=rpi

[Install]
WantedBy=multi-user.target
EOL

# Enable and start the Smashing service
sudo systemctl enable smashing
sudo systemctl start smashing

echo "Setup complete. Please reboot your system."
