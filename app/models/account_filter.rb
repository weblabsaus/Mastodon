# frozen_string_literal: true
#
# Mastodon, a GNU Social-compatible microblogging server
# Copyright (C) 2016-2017 Eugen Rochko & al (see the AUTHORS file)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

class AccountFilter
  attr_reader :params

  def initialize(params)
    @params = params
  end

  def results
    scope = Account.alphabetic
    params.each do |key, value|
      scope = scope.merge scope_for(key, value)
    end
    scope
  end

  def scope_for(key, value)
    case key
    when /local/
      Account.local
    when /remote/
      Account.remote
    when /by_domain/
      Account.where(domain: value)
    when /silenced/
      Account.silenced
    when /recent/
      Account.recent
    when /suspended/
      Account.suspended
    else
      raise "Unknown filter: #{key}"
    end
  end
end
