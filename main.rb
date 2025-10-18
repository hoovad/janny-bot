# frozen_string_literal: true

require_relative 'env'
require_relative 'database'
require 'disrb'
require 'time'

def get_user_status(discordapi, guild_id, user_id)
  guild_ban = discordapi.get_guild_ban(guild_id, user_id)
  guild_ban = if guild_ban.status == 200 && JSON.parse(guild_ban.body)['reason'].nil?
                'Not provided'
              elsif guild_ban.status == 200
                JSON.parse(guild_ban.body)['reason']
              end

  guild_member = discordapi.get_guild_member(guild_id, user_id)
  communication_disabled_until = if guild_member.status == 200
                                   JSON.parse(guild_member.body)['communication_disabled_until']
                                 end

  timeout = if defined?(communication_disabled_until) && communication_disabled_until.is_a?(String) &&
               Time.parse(communication_disabled_until) > Time.now
              Time.parse(communication_disabled_until)
            end

  if guild_ban.nil? && guild_member.status == 200 && timeout.nil?
    ['active', Time.parse(JSON.parse(guild_member.body)['joined_at'])]
  elsif guild_ban
    ['banned', guild_ban]
  elsif !timeout.nil?
    ['timeout', timeout]
  elsif guild_member.status == 404
    ['not_in_guild']
  else
    ['unknown']
  end
end

dh = DatabaseHandler.new
discordapi = DiscordApi.new(TOKEN_TYPE, TOKEN, 'all')
discordapi.create_global_application_command('ban', description: 'Bans a user from the server',
                                                    options: [{ type: 6, name: 'user',
                                                                description: 'The user to ban',
                                                                required: true },
                                                              { type: 3, name: 'reason',
                                                                description: 'The reason for the ban' }],
                                                    contexts: [0])
discordapi.create_global_application_command('kick', description: 'Kicks a user from the server',
                                                     options: [{ type: 6, name: 'user',
                                                                 description: 'The user to kick',
                                                                 required: true },
                                                               { type: 3, name: 'reason',
                                                                 description: 'The reason for the kick' }],
                                                     contexts: [0])
discordapi.create_global_application_command('cases', description: 'Gets the cases of a user (kicks, bans, etc.)',
                                                      options: [{ type: 3, name: 'user',
                                                                  description: 'The user to get cases for' \
                                                                    ' (mention,' \
                                                                    ' username (has limitations)' \
                                                                    ', or user ID. Empty' \
                                                                    ' for your cases.)' }],
                                                      contexts: [0])
# noinspection RubyScope
discordapi.connect_gateway(activities: { name: 'the naughty', type: 3 }, presence_status: 'online', presence_afk: false,
                           presence_since: true, intents: 33_281) do |interaction|
  discordapi.logger.info('Responding to interaction')
  if interaction[:d][:data][:name] == 'ban'
    if DiscordApi.reverse_permissions_integer(interaction[:d][:member][:permissions].to_i).include?(:ban_members)
      # i shouldn't hardcode the bot's ID but for now it's fine
      if interaction[:d][:data][:options][0][:value] == '1391348426624471110'
        discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                                 "type": 4,
                                                                 "data": {
                                                                   "content": ':x: what a meanie! why would you want ' \
                                                                   'to ban me? i\'m just a bot! :cry:'
                                                                 }
                                                               }))
        next
      end
      if interaction[:d][:data][:options][0][:value] == interaction[:d][:member][:user][:id]
        discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                                 "type": 4,
                                                                 "data": {
                                                                   "content": ':x: you can\'t ban yourself silly!'
                                                                 }
                                                               }))
        next
      end
      response = if interaction[:d][:data][:options][1]
                   discordapi.create_guild_ban(interaction[:d][:guild_id], interaction[:d][:data][:options][0][:value],
                                               audit_reason: interaction[:d][:data][:options][1][:value])
                 else
                   discordapi.create_guild_ban(interaction[:d][:guild_id], interaction[:d][:data][:options][0][:value])
                 end
      if response.status == 204
        discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                                 "type": 4,
                                                                 "data": {
                                                                   "content": ':white_check_mark: ' \
                                                                   'Banned user successfully!'
                                                                 }
                                                               }))
        dm_channel_id = JSON.parse(discordapi.create_dm(interaction[:d][:data][:options][0][:value]).body)['id']
        server_name = JSON.parse(discordapi.get_guild(interaction[:d][:guild_id]).body)['name']
        if interaction[:d][:data][:options][1]
          discordapi.logger.debug(discordapi.create_message(dm_channel_id, content: ':hammer: Uh oh! You have been ' \
            "banned from `#{server_name}`.\nReason: `#{interaction[:d][:data][:options][1][:value]}`." \
            "\nDuration: `permanent`."))
        else
          discordapi.logger.debug(discordapi.create_message(dm_channel_id, content: ':hammer: Uh oh! You have been ' \
            "banned from `#{server_name}`.\nReason: Not provided." \
            "\nDuration: `permanent`."))
        end
      else
        discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                                 "type": 4,
                                                                 "data": {
                                                                   "content": ':x: Failed to ban user ' \
                                                                   'with error: ' \
                                                                   "#{JSON.parse(response.body)['message']}"
                                                                 }
                                                               }))
      end
    else
      discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                               "type": 4,
                                                               "data": {
                                                                 "content": ':x: I\'m sorry! You don\'t have ' \
                                                                   'sufficient permissions to ban users.'
                                                               }
                                                             }))
    end
  end
  if interaction[:d][:data][:name] == 'kick'
    if DiscordApi.reverse_permissions_integer(interaction[:d][:member][:permissions].to_i).include?(:kick_members)
      if interaction[:d][:data][:options][0][:value] == '1391348426624471110'
        discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                                 "type": 4,
                                                                 "data": {
                                                                   "content": ':x: what a meanie! why would you want ' \
                                                                     'to kick me? i\'m just a bot! :cry:'
                                                                 }
                                                               }))
        next
      end
      if interaction[:d][:data][:options][0][:value] == interaction[:d][:member][:user][:id]
        discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                                 "type": 4,
                                                                 "data": {
                                                                   "content": ':x: you can\'t kick yourself silly!'
                                                                 }
                                                               }))
        next
      end
      response = if interaction[:d][:data][:options][1]
                   discordapi.remove_guild_member(interaction[:d][:guild_id],
                                                  interaction[:d][:data][:options][0][:value],
                                                  audit_reason: interaction[:d][:data][:options][1][:value])
                 else
                   discordapi.remove_guild_member(interaction[:d][:guild_id],
                                                  interaction[:d][:data][:options][0][:value])
                 end
      if response.status == 204
        discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                                 "type": 4,
                                                                 "data": {
                                                                   "content": ':white_check_mark: ' \
                                                                     'Kicked user successfully!'
                                                                 }
                                                               }))
        dm_channel_id = JSON.parse(discordapi.create_dm(interaction[:d][:data][:options][0][:value]).body)['id']
        server_name = JSON.parse(discordapi.get_guild(interaction[:d][:guild_id]).body)['name']
        if interaction[:d][:data][:options][1]
          discordapi.logger.debug(discordapi.create_message(dm_channel_id, content: ':hammer: You\'ve been ' \
            "kicked from `#{server_name}`.\nReason: `#{interaction[:d][:data][:options][1][:value]}`."))
        else
          discordapi.logger.debug(discordapi.create_message(dm_channel_id, content: ':hammer: You\'ve been ' \
            "kicked from `#{server_name}`.\nReason: Not provided."))
        end
      else
        discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                                 "type": 4,
                                                                 "data": {
                                                                   "content": ':x: Failed to kick user ' \
                                                                     'with error: ' \
                                                                     "#{JSON.parse(response.body)['message']}"
                                                                 }
                                                               }))
      end
    else
      discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                               "type": 4,
                                                               "data": {
                                                                 "content": ':x: I\'m sorry! You don\'t have ' \
                                                                   'sufficient permissions to kick users.'
                                                               }
                                                             }))
    end
  end
  if interaction[:d][:data][:name] == 'cases'
    if interaction[:d][:data][:options]
      case interaction[:d][:data][:options][0][:value]
      when /^<@\d+>$/
        user_id = interaction[:d][:data][:options][0][:value].scan(/<@(\d+)>/).flatten.first.to_i
        _cases = dh.get_cases(id: user_id)
      when /^\d+$/
        user_id = interaction[:d][:data][:options][0][:value].to_i
        _cases = dh.get_cases(id: interaction[:d][:data][:options][0][:value])
      when /^(?!.*\.\.)([a-z0-9_.]{2,32})$/
        user_id = String.new
        username = interaction[:d][:data][:options][0][:value]
        _cases = dh.get_cases(username: interaction[:d][:data][:options][0][:value])
      else
        discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                                 "type": 4,
                                                                 "data": {
                                                                   "content": ':x: I\'m sorry! You didnt\'t set the' \
                                                                     ' required data correctly. You must set users' \
                                                                     " to:\n - Mention the user" \
                                                                     " \n - Type in their full username (must follow" \
                                                                     " discord's username rules) (limited " \
                                                                     "functionality)\n - Type in their user ID"
                                                                 }
                                                               }))
        next
      end
    else
      user_id = interaction[:d][:member][:user][:id].to_i
      _cases = dh.get_cases(id: user_id)
    end
    response = String.new
    response += 'No cases found.' # need to implement proper cases searching, for now just return nothing
    if user_id.is_a?(String)
      matched_members = discordapi.search_guild_members(interaction[:d][:guild_id], username, 1000)
      if matched_members.status == 200 && !JSON.parse(matched_members.body).empty?
        data = { 'flags' => 32_768, 'components' => [{ 'type' => 1,
                                                       'components' => [{ 'type' => 3,
                                                                          'custom_id' => 'cases_select_user',
                                                                          'placeholder' => 'Select user' }] }] }
        options = JSON.parse(matched_members.body).map do |member|
          {
            'label' => member['user']['username'],
            'value' => member['user']['id']
          }
        end
        options.unshift({ 'label' => 'Cancel', 'value' => 'cancel' })
        options.unshift({ 'label' => 'Not here', 'value' => 'NULL' })
        data['components'][0]['components'][0]['options'] = options
      elsif matched_members.status == 200 && JSON.parse(matched_members.body).empty?
        response += 'User status: Unknown. No users with that username or similar found in server. Please set user' \
          ' to: mentioning the user, typing in their full username (if they are in the server), or their user ID.'
      else
        response += 'User status: Unknown. Internal error.'
      end
    else
      user_status = get_user_status(discordapi, interaction[:d][:guild_id], user_id)
      response += case user_status[0]
                  when 'active'
                    "\nUser status: Active. Joined at: #{user_status[1]}"
                  when 'banned'
                    "\nUser status: Banned. Reason: #{user_status[1]}"
                  when 'timeout'
                    "\nUser status: Timeout. Until: #{user_status[1]}"
                  when 'not_in_guild'
                    "\nUser status: Not in guild."
                  else
                    "\nUser status: Unknown."
                  end
    end
    if !user_id.is_a?(String)
      discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                               "type": 4,
                                                               "data": { "content": response }
                                                             }))
    elsif user_id.is_a?(String) && !data.nil?
      discordapi.logger.debug(discordapi.respond_interaction(interaction, {
                                                               'type' => 4,
                                                               'data' => data
                                                             }))
    end
    # haven't implemented component handling yet so the interaction will just error out lol
  end
end
