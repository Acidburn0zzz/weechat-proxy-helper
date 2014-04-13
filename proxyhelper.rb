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
SCRIPT_VERSION = '0.0.1'
SCRIPT_LICENSE = 'MIT'
SCRIPT_DESC = 'script to help proxying and stuff'
OUTGOING_REGEX = /^(?<command>[^ ]+)( (?<destination>[^:][^ ]*))?( :(?<text>.*))?$/

require 'json'
def load_prefixes
  File.open(@data_file_path) do |f|
    @prefixes = JSON.load f
  end
end
def save_prefixes
  File.open(@data_file_path, 'w') do |f|
    JSON.dump @prefixes, f
  end
end
def weechat_init
  Weechat.register SCRIPT_NAME, SCRIPT_AUTHOR,  SCRIPT_VERSION, SCRIPT_LICENSE,
    SCRIPT_DESC, '', ''

  Weechat.hook_command 'addprefix', 'Add a new prefix for the current server.',
    'addprefix <prefix> <server>',
    'addprefix <prefix> <server> - On the current server, a message beginning with <prefix> will instead be sent through <server> if the current channel exists on <server>.',
    '%(irc_servers)',
    'addprefix_cmd_callback',
    ''
  Weechat.hook_command 'listprefixes', 'list all configured prefixes',
    'listprefixes',
    'listprefixes - list all configured prefixes',
    '',
    'listprefixes_cmd_callback',
    ''
  Weechat.hook_command 'delprefix', 'delete a prefix on the current server',
    'delprefix <prefix>',
    'delprefix <prefix> - Delete the given prefix from the current server',
    '',
    'delprefix_cmd_callback',
    ''
  Weechat.hook_modifier 'irc_out1_privmsg', 'modifier_callback', ''

  @prefixes = Hash.new { |h, k| h[k] = {} }
  @data_file_path = "#{Weechat.info_get 'weechat_dir', ''}/#{SCRIPT_NAME}.conf"
  load_prefixes if File.exists? @data_file_path

  Weechat::WEECHAT_RC_OK
end

def addprefix_cmd_callback data, buf, args
  #Weechat.print '', @prefixes.to_s
  srv = Weechat.buffer_get_string buf, 'localvar_server'
  if srv.empty?
    Weechat.print '', "#{Weechat.prefix 'error'}unable to find the server of the current buffer"
    return Weechat::WEECHAT_RC_ERROR
  end
  pfx, dest = args.split.take 2
  if pfx.nil? or dest.nil?
    Weechat.print '', "#{Weechat.prefix 'error'}not enough arguments"
    return Weechat::WEECHAT_RC_ERROR
  end
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
  @prefixes[srv][pfx] = dest
  save_prefixes

  Weechat::WEECHAT_RC_OK
end

def delprefix_cmd_callback data, buf, args
  srv = Weechat.buffer_get_string buf, 'localvar_server'
  if srv.empty?
    Weechat.print '', "#{Weechat.prefix 'error'}unable to find the server of the current buffer"
    return Weechat::WEECHAT_RC_ERROR
  end
  pfx = args.split.first
  if pfx.nil?
    Weechat.print '', "#{Weechat.prefix 'error'}not enough arguments"
    return Weechat::WEECHAT_RC_ERROR
  end
  if @prefixes[srv][pfx]
    old_dest = @prefixes[srv].delete pfx
    Weechat.print Weechat.current_buffer, "prefix #{pfx} mapping to #{old_dest} removed"
  else
    Weechat.print Weechat.current_buffer, "#{Weechat.prefix 'error'}prefix #{pfx} not found for the current server"
  end
  save_prefixes

  Weechat::WEECHAT_RC_OK
end

def listprefixes_cmd_callback data, buf, args
  str = JSON.pretty_generate @prefixes
  Weechat.print '', str
  Weechat::WEECHAT_RC_OK
end

def modifier_callback data, modifier, modifier_data, string
  #Weechat.print '', "current server has modifiers: #{@prefixes[modifier_data]}"
  #Weechat.print '', string
  srv = Weechat.buffer_get_string Weechat.current_buffer, 'localvar_server'
  return string unless @prefixes[srv] and @prefixes[srv].keys
  match = string.match OUTGOING_REGEX
  command = match[:command]
  dest    = match[:destination]
  text    = match[:text]
  return string unless dest.start_with? '#'

  if srv.empty?
    Weechat.print '', "#{Weechat.prefix 'error'}unable to find the server of the current buffer"
    return Weechat::WEECHAT_RC_ERROR
  end

  #Weechat.print '', "cmd: #{command}, dest: #{dest}, text: #{text}"
  @prefixes[srv].each_pair do |k, v|
    if text.start_with? k
      buf = Weechat.buffer_search 'irc', "#{v}.#{dest}"
      return string if buf.empty?
      text.sub! k, ''
      Weechat.command buf, text
      return ""
    end
  end

  string
end
