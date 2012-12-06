exportObj = exports ? this

# Assumes that cards.js has been loaded already and data is on exportObj.

exportObj.sortHelper = (a, b) ->
    if a.points == b.points
        a_name = a.name.replace(/[^a-z0-9]/ig, '')
        b_name = b.name.replace(/[^a-z0-9]/ig, '')
        if a_name == b_name
            0
        else
            if a_name > b_name then 1 else -1
    else
        if a.points > b.points then 1 else -1

# ripped from http://stackoverflow.com/questions/901115/how-can-i-get-query-string-values
exportObj.getParameterByName = (name) ->
  name = name.replace(/[\[]/, "\\\[").replace(/[\]]/, "\\\]")
  regexS = "[\\?&]" + name + "=([^&#]*)"
  regex = new RegExp(regexS)
  results = regex.exec(window.location.search)
  if results == null
    return ""
  else
    return decodeURIComponent(results[1].replace(/\+/g, " "))

$.isMobile = () ->
    navigator.userAgent.match /(iPhone|iPod|iPad|Android)/i

class exportObj.SquadBuilder
    # Superclass for faction builders.
    # Tracks which pilots are in use.
    #
    # Usage:
    #
    #   sb = new SquadBuilder
    #       container: '#empire-builder'
    #       faction: "Galactic Empire"
    constructor: (args) ->
        # arguments
        @container = $(args.container)
        @faction = args.faction
        @pilot_tooltip = $(args.pilot_tooltip)
        @upgrade_tooltip = $(args.upgrade_tooltip)
        @list_modal = $(args.list_modal)

        # internal state
        @rows = []
        @pilots = []
        @unique_upgrades = []

        @pilot_tooltip.hide()
        @upgrade_tooltip.hide()

        # Add status row
        @status_row = $(document.createElement 'DIV')
        @status_row.addClass 'row'
        @container.append @status_row

        @points_cell = $(document.createElement 'DIV')
        @points_cell.addClass 'three columns total-points'
        @points_cell.text 'Points: 0'
        @status_row.append @points_cell

        permalink_cell = $(document.createElement 'DIV')
        permalink_cell.addClass 'three columns permalink'
        @status_row.append permalink_cell
        @permalink = $(document.createElement 'A')
        @permalink.text 'Permalink'
        @permalink.attr 'href', '#'
        permalink_cell.append @permalink

        # Add pilot button
        @button_row = $(document.createElement 'DIV')
        @button_row.addClass 'row'
        @container.append @button_row
        button_cell = $(document.createElement 'DIV')
        button_cell.addClass 'twelve columns'
        @button_row.append button_cell
        @view_list_button = $(document.createElement 'BUTTON')
        @view_list_button.addClass 'nice radius button'
        @view_list_button.text 'View list as text'
        @view_list_button.click (e) =>
            e.preventDefault()
            @list_modal.reveal()
        button_cell.append @view_list_button
        @view_list_button.hide()

        $(window).bind 'xwing:pilotChanged', (e, triggering_row) =>
            @pilots = (row.name for row in @rows when row.name? and row.name != '')
            for row in @rows
                if row != triggering_row
                    row.update()
            @updatePoints()
            @pilot_tooltip.hide()
            if @rows.length == @pilots.length
                @rows.push new PilotRow this
            @updatePermalink()
            if @pilots.length > 0
                @view_list_button.show()
            else
                @view_list_button.hide()

        $(window).bind 'xwing:upgradeChanged', (e, triggering_selector) =>
            @unique_upgrades = []
            for row in @rows
                for upgrade_selector in row.upgrade_selectors
                    if upgrade_selector.upgrade?.unique?
                        @unique_upgrades.push(upgrade_selector.upgrade_name)
            # Update the other selectors
            for row in @rows
                for upgrade_selector in row.upgrade_selectors
                    if upgrade_selector != triggering_selector
                        upgrade_selector.update()
            @updatePoints()
            @upgrade_tooltip.hide()
            @updatePermalink()

        # Add initial row; need at least one row present for loadFromSerialized to work properly.
        @rows.push new PilotRow this
        # Check if there's data for us to deserialize.
        if exportObj.getParameterByName('f') == @faction
            @loadFromSerialized exportObj.getParameterByName('d')

    updatePoints: () ->
        total = 0
        for row in @rows
            row_points = 0
            if row.name? and row.name != ''
                pilot_points = parseInt row.pilot.points
                total += pilot_points
                row_points += pilot_points
            for selector in row.upgrade_selectors
                upgrade_points = parseInt(exportObj.upgrades[selector.upgrade_name]?.points ? 0)
                total += upgrade_points
                row_points += upgrade_points
            row.pilot_points_cell.text row_points
        @points_cell.text "Points: #{total}"
        @list_modal.find('span.total').text total

    updatePermalink: () ->
        @permalink.attr 'href', "#{window.location.href.split('?')[0]}?f=#{encodeURI @faction}&d=#{encodeURI @serialize()}"

    getAvailablePilots: () ->
        # Returns list of available pilot names for this faction.
        ships = (ship_name for ship_name, ship_data of exportObj.ships when ship_data.faction == @faction)
        ({name: pilot_name, points: pilot_data.points, ship: pilot_data.ship} for pilot_name, pilot_data of exportObj.pilots when pilot_data.ship in ships and (not pilot_data.unique? or pilot_name not in @pilots))

    getAvailableUpgrades: (slot) ->
        ({name: upgrade_name, points: upgrade_data.points} for upgrade_name, upgrade_data of exportObj.upgrades when upgrade_data.slot == slot and upgrade_name not in @unique_upgrades).sort exportObj.sortHelper

    showPilotInfo: (elem, pilot_name, pilot_data, ship) ->
        if pilot_name? and pilot_name != ''
            @pilot_tooltip.find('.ship td').text pilot_data.ship
            @pilot_tooltip.find('.flavortext').text pilot_data.text ? ''
            @pilot_tooltip.find('.attack td').text ship.attack
            @pilot_tooltip.find('.agility td').text ship.agility
            @pilot_tooltip.find('.hull td').text ship.hull
            @pilot_tooltip.find('.shields td').text ship.shields
            @pilot_tooltip.find('.actions td').text ship.actions.join ', '

            reference_pos = $(elem).offset()
            @pilot_tooltip.css 'width', parseInt($(elem).css('width')) + 'px'
            @pilot_tooltip.css 'top', reference_pos.top + parseInt($(elem).css('height')) + 'px'
            @pilot_tooltip.css 'left', reference_pos.left + 'px'

            @pilot_tooltip.show()

    showUpgradeInfo: (elem, upgrade_name, upgrade_data) ->
        if upgrade_name? and upgrade_name != ''
            $('table.weapon-stats').hide()
            if upgrade_data.attack?
                @upgrade_tooltip.find('tr.attack').show()
                @upgrade_tooltip.find('tr.attack td').text upgrade_data.attack
                $('table.weapon-stats').show()
            else
                @upgrade_tooltip.find('tr.attack').hide()
            if upgrade_data.range?
                @upgrade_tooltip.find('tr.range').show()
                @upgrade_tooltip.find('tr.range td').text upgrade_data.range
                $('table.weapon-stats').show()
            else
                @upgrade_tooltip.find('tr.range').hide()
            @upgrade_tooltip.find('.flavortext').text upgrade_data.text

            reference_pos = $(elem).offset()
            @upgrade_tooltip.css 'width', parseInt($(elem).css('width')) + 'px'
            @upgrade_tooltip.css 'top', reference_pos.top + parseInt($(elem).css('height')) + 'px'
            @upgrade_tooltip.css 'left', reference_pos.left + 'px'

            @upgrade_tooltip.show()

    serialize: () ->
        # PILOT_ID:UPGRADEID1,UPGRADEID2; ...
        ( "#{row.pilot.id}:#{( selector.upgrade?.id ? -1 for selector in row.upgrade_selectors ).join ','}" for row in @rows when row.name? and row.name != '' ).join ';'

    loadFromSerialized: (serialized) ->
        for row in @rows
            row.destroy () =>
                # When the last one is gone, there will be one empty one...
                if @rows.length == 1
                    for pilot_str in serialized.split ';'
                        [pilot_id, upgrade_list] = pilot_str.split ':'
                        pilot_id = parseInt pilot_id
                        new_pilot_row = new PilotRow this
                        new_pilot_row.pilot_selector.val (pilot_name for pilot_name, pilot_data of exportObj.pilots when parseInt(pilot_data.id) == pilot_id)[0]
                        new_pilot_row.pilot_selector.change()
                        for upgrade_id, i in upgrade_list.split ','
                            upgrade_id = parseInt upgrade_id
                            if upgrade_id >= 0
                                selector = new_pilot_row.upgrade_selectors[i]
                                selector.selector.val (upgrade_name for upgrade_name, upgrade_data of exportObj.upgrades when parseInt(upgrade_data.id) == upgrade_id)
                                selector.selector.change()
                        @rows.push new_pilot_row
                    $('select').trigger 'liszt:updated'
                # And then remove that initial one.
                @rows[0].destroy()

class PilotRow
    # Represents a pilot row in the UI.
    constructor: (builder) ->
        @builder = builder
        @name = null
        @pilot = null
        @ship = null
        @upgrade_selectors = []

        # set up UI elements
        @row = $(document.createElement 'DIV')
        @row.addClass 'row pilot'
        @row.insertBefore @builder.button_row

        @pilot_cell = $(document.createElement 'DIV')
        @pilot_cell.addClass 'four columns'
        @row.append @pilot_cell

        @pilot_selector = $(document.createElement 'SELECT')
        opt = $(document.createElement 'OPTION')
        if $.isMobile()
            opt.text 'Select a pilot'
            opt.val ''
            opt.attr 'disabled', true
        @pilot_selector.append opt
        @pilot_selector.addClass 'pilot'
        @pilot_selector.attr 'data-placeholder', 'Select a pilot'
        @pilot_selector.change (e) =>
            # Clear upgrades
            @upgrade_cell.text ''
            @upgrade_selectors = []
            @name = @pilot_selector.val()
            for cls in @row.attr('class').split ' '
                if cls.indexOf('ship-') == 0
                    @row.removeClass cls
            if @name == ''
                @destroy()
            else
                @pilot = exportObj.pilots[@name]
                @ship = exportObj.ships[@pilot.ship]
                #  Set upgrade selectors
                for slot in @pilot.slots
                    @upgrade_selectors.push new UpgradeSelector this, slot, @upgrade_cell
                shipbg_class = switch @pilot.ship
                    when 'X-Wing'
                        "xwing1"
                    when 'Y-Wing'
                        "ywing0"
                    when 'TIE Fighter'
                        "tiefighter0"
                    when 'TIE Advanced'
                        "tieadvanced0"
                    else
                        null
                if shipbg_class?
                    @row.addClass "ship-#{shipbg_class}"
                @remove_cell.fadeIn 'fast'

                @list_dd.text "#{@name} (#{@pilot.points})"
                @pilot_points_cell.show()

            $(window).trigger 'xwing:pilotChanged', this
        @pilot_cell.append @pilot_selector
        if not $.isMobile()
            @pilot_selector.chosen
                search_contains: true
        # mouseover handler
        $("##{@pilot_selector.attr 'id'}_chzn a.chzn-single").mouseover (e) =>
            @builder.showPilotInfo $(e.delegateTarget), @name, @pilot, @ship
        $("##{@pilot_selector.attr 'id'}_chzn a.chzn-single").mouseleave (e) =>
            @builder.pilot_tooltip.hide()
        $("##{@pilot_selector.attr 'id'}_chzn a.chzn-single").click (e) =>
            @builder.pilot_tooltip.hide()

        @pilot_points_cell = $(document.createElement 'DIV')
        @pilot_points_cell.addClass 'one column points'
        @row.append @pilot_points_cell
        @pilot_points_cell.hide()

        @upgrade_cell = $(document.createElement 'DIV')
        @upgrade_cell.addClass 'six columns upgrades'
        @row.append @upgrade_cell

        @remove_cell = $(document.createElement 'DIV')
        @remove_cell.addClass 'one column'
        @remove_cell.append """<a class="small alert radius button remove">&#215;</span>"""
        @remove_cell.click (e) =>
            e.preventDefault()
            @destroy()
        @row.append @remove_cell
        @remove_cell.hide()

        # Add to text list
        @list_dd = $(document.createElement 'DD')
        @builder.list_modal.find('dl').append @list_dd
        @list_dt = $(document.createElement 'DT')
        @builder.list_modal.find('dl').append @list_dt
        @list_ul = $(document.createElement 'UL')
        @list_dt.append @list_ul

        @update()
        #@pilot_selector.change()

    update: () ->
        # Update the contents of the selector when another pilot is selected

        available_pilots = @builder.getAvailablePilots()
        # Re-add our selected pilot if there is one
        if @pilot
            available_pilots.push
                name: @name
                points: @pilot.points
                ship: @pilot.ship
        # Organize by ship
        pilots_by_ship = {}
        for pilot in available_pilots
            pilots_by_ship[pilot.ship] = [] if pilot.ship not of pilots_by_ship
            pilots_by_ship[pilot.ship].push pilot
        for ship, pilots of pilots_by_ship
            pilots.sort exportObj.sortHelper

        @pilot_selector.text ''
        opt = $(document.createElement 'OPTION')
        if $.isMobile()
            opt.text "Select a pilot"
            opt.val ''
            opt.attr 'disabled', true
        @pilot_selector.append opt
        for ship in Object.keys(pilots_by_ship).sort()
            optgroup = $(document.createElement 'OPTGROUP')
            optgroup.attr 'label', ship
            @pilot_selector.append optgroup
            for pilot in pilots_by_ship[ship]
                option = $(document.createElement 'OPTION')
                option.text "#{pilot.name} (#{pilot.points})"
                option.val pilot.name
                optgroup.append option

        @pilot_selector.val @name
        @pilot_selector.trigger 'liszt:updated'

    destroy: (callback=$.noop) ->
        # Deregister everything from the builder and remove this row.
        @row.slideUp 'fast', () =>
            @row.remove()
            @list_dd.remove()
            @list_dt.remove()
            @list_ul.remove()
            @builder.rows.splice @builder.rows.indexOf(this), 1
            $(window).trigger 'xwing:pilotChanged', null
            $(window).trigger 'xwing:upgradeChanged', null
            callback()

class UpgradeSelector
    # Represents an upgrade selector in the UI.

    constructor: (row, slot, container) ->
        @row = row
        @builder = @row.builder
        @slot = slot
        @upgrade_name = null
        @upgrade = null

        @selector = $(document.createElement 'SELECT')
        opt = $(document.createElement 'OPTION') # required for allow_single_deselect
        if $.isMobile()
            opt.text "No #{@slot} Upgrade"
            opt.val ''
        @selector.append opt
        @selector.addClass 'upgrade'
        @selector.attr 'data-placeholder', "Select #{@slot} Upgrade"
        @selector.change (e) =>
            @upgrade_name = @selector.val()
            @upgrade = exportObj.upgrades[@selector.val()]
            if @upgrade_name? and @upgrade_name != ''
                @list_li.show()
                @list_li.text "#{@upgrade_name} (#{@upgrade.points})"
            else
                @list_li.hide()
            $(window).trigger 'xwing:upgradeChanged', @selector
        container.append @selector
        if not $.isMobile()
            @selector.chosen
                search_contains: true
                allow_single_deselect: true
                disable_search_threshold: 8
        $("##{@selector.attr 'id'}_chzn a.chzn-single").mouseover (e) =>
            @builder.showUpgradeInfo $(e.delegateTarget), @upgrade_name, @upgrade
        $("##{@selector.attr 'id'}_chzn a.chzn-single").mouseleave (e) =>
            @builder.upgrade_tooltip.hide()
        $("##{@selector.attr 'id'}_chzn a.chzn-single").click (e) =>
            @builder.upgrade_tooltip.hide()

        @list_li = $(document.createElement 'LI')
        @row.list_ul.append @list_li
        @list_li.hide()

        @update()
        #@selector.change()

    update: () ->
        available_upgrades = @builder.getAvailableUpgrades @slot
        # re-add our upgrade
        if @upgrade and @upgrade.unique?
            available_upgrades.push
                name: @upgrade_name
                points: @upgrade.points
        available_upgrades.sort exportObj.sortHelper

        @selector.text ''
        opt = $(document.createElement 'OPTION') # required for allow_single_deselect
        if $.isMobile()
            opt.text "No #{@slot} Upgrade"
            opt.val ''
        @selector.append opt
        for upgrade in available_upgrades
            option = $(document.createElement 'OPTION')
            option.text "#{upgrade.name} (#{upgrade.points})"
            option.val upgrade.name
            @selector.append option
        @selector.val @upgrade_name
        @selector.trigger 'liszt:updated'