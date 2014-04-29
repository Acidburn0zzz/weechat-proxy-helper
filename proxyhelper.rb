#Copyright (c) 2014 Rylee Fowler <rylee@rylee.me>
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in
#all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#THE SOFTWARE.

SCRIPT_NAME = 'proxyhelper'
SCRIPT_AUTHOR = 'Rylee Fowler'
SCRIPT_VERSION = '0.0.2'
SCRIPT_LICENSE = 'MIT'
SCRIPT_DESC = 'script to help proxying and stuff'
OUTGOING_REGEX = /^(?<command>[^ ]+)( (?<destination>[^:][^ ]*))?( :(?<text>.*))?$/

require 'json'
def load_prefixes
  File.open(@data_file_path) do |f|
    @prefixes = JSON.load f
  end
  if @prefixes.first[1].first[1].is_a?(String) || @prefixes.first[1].first[1].is_a?(Array)
    convert_prefixes
  end
end
def save_prefixes
  File.open(@data_file_path, 'w') do |f|
    JSON.dump @prefixes, f
  end
end
def convert_prefixes
  @prefixes.each do |server, prefixes|
    prefixes.each do |pfx, destination|
      type = nil
      if destination.is_a? String
        type = 'server'
      elsif destination.is_a? Array
        type = 'fifo'
      else
        return Weechat::WEECHAT_RC_ERROR
      end
      prefixes[pfx] = {'destination' => destination, 'type' => type}
    end
  end
end

def weechat_init
  Weechat.register SCRIPT_NAME, SCRIPT_AUTHOR,  SCRIPT_VERSION, SCRIPT_LICENSE,
    SCRIPT_DESC, '', ''

  Weechat.hook_command 'prefix', 'Manage prefix mappings.',
    'add server <prefix> <destination_server> | add fifo <prefix> <remote_server_name> <directory> | del <prefix> | list',
    [
      'add server <prefix> <destination_server>',
      '  adds an in-weechat prefix mapping from <prefix> on the current server pointing at <destination_server>',
      'add fifo <prefix> <remote_server_name> <directory>',
      '  adds a FIFO mapping from <prefix> on the current server pointing at <remote_server_name> that has a FIFO located in <directory>',
      '  note: this takes the *directory* where the FIFO is located, not the location of the FIFO itself',
      '  it will look for a file matching the glob pattern "weechat_fifo_*" and take the first match',
      'del <prefix>',
      '  deletes the mapping from <prefix> to any FIFO or server mappings it has',
      'list',
      '  lists all prefix mappings on all servers'
    ].join("\n"),
    [
      'add server <prefix> %(irc_servers)',
      'add fifo <prefix> <remote_server_name> <directory>',
      'del <prefix>',
      'list'
    ].join(' || '),
    'cmd_callback',
    ''

    Weechat.hook_modifier 'irc_out1_privmsg', 'modifier_callback', ''

    @prefixes = Hash.new { |h, k| h[k] = {} }
    @data_file_path = "#{Weechat.info_get 'weechat_dir', ''}/#{SCRIPT_NAME}.conf"
    load_prefixes if File.exists? @data_file_path

    Weechat::WEECHAT_RC_OK
end

def cmd_callback data, buf, args
  cmd, param = args.split /\s/, 2
  srv = Weechat.buffer_get_string buf, 'localvar_server'
  case cmd.downcase
  when 'add'
    if param.nil?
      Weechat.print Weechat.current_buffer, "#{Weechat.prefix 'error'}Now that's just not right. That command needs parameters."
      return Weechat::WEECHAT_RC_ERROR
    end
    if srv.empty?
      Weechat.print '', "#{Weechat.prefix 'error'}unable to find the server of the current buffer"
      return Weechat::WEECHAT_RC_ERROR
    end
    type, rest = param.split /\s/, 2
    case type.downcase
    when 'server'
      pfx, dest = rest.split(/\s/, 2)
      if pfx.nil? or dest.nil?
        Weechat.print '', "#{Weechat.prefix 'error'}not enough arguments"
        return Weechat::WEECHAT_RC_ERROR
      end

      add_prefix_server srv, pfx, dest
    when 'fifo'
      Weechat.print '', rest
      pfx, remote_server, dest = rest.split(/\s/, 3)
      if pfx.nil? or dest.nil? or remote_server.nil?
        Weechat.print '', "#{Weechat.prefix 'error'}not enough arguments"
        return Weechat::WEECHAT_RC_ERROR
      end
      add_prefix_fifo srv, pfx, remote_server, dest
    end

  when 'del'
    if param.nil?
      Weechat.print Weechat.current_buffer, "#{Weechat.prefix 'error'}Now that's just not right. That command needs parameters."
      return Weechat::WEECHAT_RC_ERROR
    end
    if srv.empty?
      Weechat.print '', "#{Weechat.prefix 'error'}unable to find the server of the current buffer"
      return Weechat::WEECHAT_RC_ERROR
    end

    pfx = param.split.first
    if pfx.nil?
      Weechat.print '', "#{Weechat.prefix 'error'}not enough arguments"
      return Weechat::WEECHAT_RC_ERROR
    end

    delete_prefix srv, pfx

  when 'list'
    list_prefixes

  end

end

def list_prefixes
  str = JSON.pretty_generate @prefixes
  Weechat.print '', str

  Weechat::WEECHAT_RC_OK
end

def delete_prefix srv, pfx
  if @prefixes[srv][pfx]
    old_dest = @prefixes[srv].delete pfx
    Weechat.print Weechat.current_buffer, "prefix #{pfx} mapping to #{old_dest} removed"
  else
    Weechat.print Weechat.current_buffer, "#{Weechat.prefix 'error'}prefix #{pfx} not found for the current server"
  end
  save_prefixes

  Weechat::WEECHAT_RC_OK
end

def add_prefix_fifo srv, pfx, remote_server, dest
  if @prefixes[srv]
    @prefixes[srv].each_key do |p|
      if p.start_with? pfx
        Weechat.print Weechat.current_buffer, "#{Weechat.prefix 'error'}Attempted to add the prefix #{pfx} but it conflicted with #{p} which maps to #{@prefixes[srv][p]}!"
        return Weechat::WEECHAT_RC_ERROR
      end
    end
  else
    @prefixes[srv] = {}
  end
  Weechat.print '', "Added prefix #{pfx} on #{srv} mapping to #{dest}"
  @prefixes[srv][pfx] = {}
  @prefixes[srv][pfx]['destination'] = []
  @prefixes[srv][pfx]['destination'][0] = dest
  @prefixes[srv][pfx]['destination'][1] = remote_server
  @prefixes[srv][pfx]['type'] = 'fifo'
  save_prefixes

  Weechat::WEECHAT_RC_OK
end

def add_prefix_server srv, pfx, dest
  if @prefixes[srv]
    @prefixes[srv].each_key do |p|
      if p.start_with? pfx
        Weechat.print Weechat.current_buffer, "#{Weechat.prefix 'error'}Attempted to add the prefix #{pfx} but it conflicted with #{p} which maps to #{@prefixes[srv][p]}!"
        return Weechat::WEECHAT_RC_ERROR
      end
    end
  else
    @prefixes[srv] = {}
  end
  if Weechat.buffer_search('irc', "server.#{dest}").empty?
    Weechat.print Weechat.current_buffer, "#{Weechat.prefix 'error'}unable to find that destination buffer, things might not work as intended"
  end
  Weechat.print '', "Added prefix #{pfx} on #{srv} mapping to #{dest}"
  @prefixes[srv][pfx] = {}
  @prefixes[srv][pfx]['destination'] = dest
  @prefixes[srv][pfx]['type'] = 'server'
  save_prefixes

  Weechat::WEECHAT_RC_OK
end

def send_msg dest, chan, text
  case dest['type'].downcase
  when 'server'
    buf = Weechat.buffer_search 'irc', "#{dest['destination']}.#{chan}"
    if buf.empty?
      Weechat.print Weechat.current_buffer, "#{Weechat.prefix 'error'}unable to find that destination buffer, is the other connection in this channel?"
      return Weechat::WEECHAT_RC_OK
    end
    Weechat.command buf, text

    Weechat::WEECHAT_RC_OK
  when 'fifo'
    File.open(Dir["#{dest['destination'].first}/weechat_fifo_*"].first, 'w') do |fifo|
      fifo.puts "irc.#{dest['destination'].last}.#{chan} *#{text}"
    end

    Weechat::WEECHAT_RC_OK
  end
end

def modifier_callback data, modifier, modifier_data, string
  srv = Weechat.buffer_get_string Weechat.current_buffer, 'localvar_server'
  return string unless @prefixes[srv] and @prefixes[srv].keys

  match = string.match OUTGOING_REGEX
  command = match[:command]
  chan    = match[:destination]
  text    = match[:text]
  return string unless chan.start_with? '#'

  if srv.empty?
    Weechat.print '', "#{Weechat.prefix 'error'}unable to find the server of the current buffer"
    return Weechat::WEECHAT_RC_ERROR
  end

  @prefixes[srv].each_pair do |prefix, destination|
    if text.start_with? prefix
      send_msg destination, chan, text.sub(prefix, '')
      return ''
    end
  end

  string
end
