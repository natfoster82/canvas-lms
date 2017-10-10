#
# Copyright (C) 2013 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

define [
  'i18n!discussions'
  'jquery'
  'underscore'
  'Backbone'
  'jsx/shared/conditional_release/CyoeHelper'
  'jsx/move_item_tray/NewMoveDialogView'
  'jst/DiscussionTopics/discussion'
  'compiled/models/DiscussionTopic'
  'compiled/views/PublishIconView'
  'compiled/views/LockIconView'
  'compiled/views/ToggleableSubscriptionIconView'
  'compiled/views/assignments/DateDueColumnView'
  'compiled/views/MoveDialogView'
], (I18n, $, _, {View}, CyoeHelper, NewMoveDialogView, template, DiscussionTopic, PublishIconView, LockIconView, ToggleableSubscriptionIconView, DateDueColumnView, MoveDialogView) ->

  class DiscussionView extends View
    # Public: View template (discussion).
    template: template

    # Public: Wrap everything in an <li />.
    tagName: 'li'

    # Public: <li /> class name(s).
    className: 'discussion'

    # Public: I18n translations.
    messages:
      confirm:     I18n.t('confirm_delete_discussion_topic', 'Are you sure you want to delete this discussion topic?')
      delete:       I18n.t('delete', 'Delete')
      user_subscribed: I18n.t('subscribed_hint', 'You are subscribed to this topic. Click to unsubscribe.')
      user_unsubscribed: I18n.t('unsubscribed_hint', 'You are not subscribed to this topic. Click to subscribe.')
      deleteSuccessful: I18n.t('flash.removed', 'Discussion Topic successfully deleted.')
      deleteFail: I18n.t('flash.fail', 'Discussion Topic deletion failed.')

    events:
      'click .icon-lock':            'toggleLocked'
      'click .icon-pin':             'togglePinned'
      'click .icon-trash':           'onDelete'
      'click .icon-updown':          'onMove'
      'click .duplicate-discussion': 'onDuplicate'
      'click':                       'onClick'

    # Public: Option defaults.
    defaults:
      pinnable: false

    els:
      '.screenreader-only': '$title'
      '.discussion-row': '$row'
      '.move_item': '$moveItemButton'
      '.move_panel': '$movePanel'
      '.discussion-actions .al-trigger': '$gearButton'

    # Public: Topic is able to be locked/unlocked.
    @optionProperty 'lockable'

    # Public: Topic is able to be pinned/unpinned.
    @optionProperty 'pinnable'

    @child 'publishIcon', '[data-view=publishIcon]' if ENV.permissions.publish

    @child 'lockIconView', '[data-view=lock-icon]'

    @child 'toggleableSubscriptionIcon', '[data-view=toggleableSubscriptionIcon]'

    @child 'dateDueColumnView', '[data-view=date-due]'

    initialize: (options) ->
      @attachModel()
      @lockIconView = false
      if ENV.permissions.manage_content
        @lockIconView = new LockIconView({
          model: @model,
          unlockedText: I18n.t("%{name} is unlocked. Click to lock.", name: @model.get('title')),
          lockedText: I18n.t("%{name} is locked. Click to unlock", name: @model.get('title')),
          course_id: ENV.COURSE_ID,
          content_id: @model.get('id'),
          content_type: 'discussion_topic'
        })
      if ENV.permissions.publish
        options.publishIcon = new PublishIconView({
          model: @model,
          title: @model.get('title')
        })
      options.toggleableSubscriptionIcon = new ToggleableSubscriptionIconView(model: @model)
      if @model.get('assignment')
        options.dateDueColumnView = new DateDueColumnView(model: @model.get('assignment'))
      @newModalView = new NewMoveDialogView
        model: @model
        nested: false
        closeTarget: @$el.find('a[id=manage_link]')
        saveURL: @model.collection.reorderURL()
        onSuccessfulMove: @onSuccessfulMove
        movePanelParent: document.getElementById('not_right_side')
        modalTitle: I18n.t('Move Discussion')
      super

    render: ->
      super
      @$el.attr('data-id', @model.get('id'))
      @newModalView.setCloseFocus @$gearButton
      this

    # Public: Lock or unlock the model and update it on the server.
    #
    # e - Event object.
    #
    # Returns nothing.
    toggleLocked: (e) =>
      e.preventDefault()
      locked = !@model.get('locked')
      pinned = if locked then false else @model.get('pinned')
      @model.updateBucket(locked: locked, pinned: pinned)
      @render()
      @$gearButton.focus()

    # Public: Confirm a request to delete and then complete it if needed.
    #
    # e - Event object.
    #
    # Returns nothing.
    onDelete: (e) =>
      e.preventDefault()
      if confirm(@messages.confirm)
        @goToPrevItem()
        @delete()
      else
        @$el.find('a[id=manage_link]').focus()

    # Public: Called when move menu item is selected
    #
    # Returns nothing.
    onMove: () =>
      @newModalView.renderOpenMoveDialog();

    # Public: Moves the items currently in the list to match backend
    #
    # movedItems - List of ID's of correct order
    #
    # Returns nothing.
    onSuccessfulMove: (movedItems) =>
      newCollection = @model.collection
      #update all of the position attributes
      positions = [1..newCollection.length]
      movedItems.forEach (id, index) ->
        newCollection.get(id)?.set 'position', positions[index]
      newCollection.sort()
      # finally, call reset to trigger a re-render
      newCollection.reset newCollection.models

    insertDuplicatedDiscussion: (response) =>
      index = @model.collection.indexOf(@model) + 1
      # TODO: Figure out how to get rid of this hack.  Don't understand why
      # the Backbone models aren't reading the JSON properly.
      topic = new DiscussionTopic(response.data)
      fixedJSON = topic.parse(response.data)
      topic = new DiscussionTopic(fixedJSON)

      @model.collection.add(topic, { at: index })
      @focusOnModel(@model.collection.at(index))

    onDuplicate: (e) =>
      e.preventDefault()
      @model.duplicate(ENV.COURSE_ID, @insertDuplicatedDiscussion)

    # Public: Delete the model and update the server.
    #
    # Returns nothing.
    delete: ->
      @model.destroy
        success : =>
          $.flashMessage @messages.deleteSuccessful
        error : =>
          $.flashError @messages.deleteFail

    goToPrevItem: =>
      if @previousDiscussionInGroup()?
        @focusOnModel(@previousDiscussionInGroup())
      else if @model.get('pinned')
        $('.pinned&.discussion-list').attr("tabindex",-1).focus()
      else if @model.get('locked')
        $('.locked&.discussion-list').attr("tabindex",-1).focus()
      else
        $('.open&.discussion-list').attr("tabindex",-1).focus()

    previousDiscussionInGroup: =>
      current_index = @model.collection.models.indexOf(@model)
      @model.collection.models[current_index - 1]

    focusOnModel: (discussionTopic) =>
      $("##{discussionTopic.id}_discussion_content").attr("tabindex",-1).focus()

    # Public: Pin or unpin the model and update it on the server.
    #
    # e - Event object.
    #
    # Returns nothing.
    togglePinned: (e) =>
      e.preventDefault()
      @model.updateBucket(pinned: !@model.get('pinned'))

    # Public: Treat the whole <li /> as a link.
    #
    # e - Event handler.
    #
    # Returns nothing.
    onClick: (e) ->
      # Workaround a behavior of FF 15+ where it fires a click
      # after dropping a sortable item.
      return if @model.get('preventClick')
      return if ['A', 'I'].includes(e.target.nodeName)
      window.location = @model.get('html_url')

    # Public: Toggle the view model's "hidden" attribute.
    #
    # Returns nothing.
    hide: =>
      @$el.toggle(!@model.get('hidden'))

    # Public: Generate JSON to pass to the view.
    #
    # Returns an object.
    toJSON: ->
      base = Object.assign(@model.toJSON(), @options)
      # handle a student locking their own discussion (they should lose permissions).
      if @model.get('locked') and !_.intersection(ENV.current_user_roles, ['teacher', 'ta', 'admin']).length
        base.permissions.delete = false

      if base.last_reply_at
        base.display_last_reply_at = I18n.l "#date.formats.medium", base.last_reply_at
      base.ENV = ENV
      base.discussion_topic_menu_tools = ENV.discussion_topic_menu_tools
      base.discussion_topic_menu_tools.forEach (tool) =>
        tool.url = tool.base_url + "&discussion_topics[]=#{@model.get("id")}"

      base.cannot_delete_by_master_course = @model.get('is_master_course_child_content') && @model.get('restricted_by_master_course')

      base.cyoe = CyoeHelper.getItemData(base.assignment_id)
      base.return_to = encodeURIComponent window.location.pathname
      base

    # Internal: Re-render for publish state change preserving focus
    #
    # Returns nothing.
    renderPublishChange: =>
      @publishIcon?.render()
      if ENV.permissions.publish
        if @model.get('published')
          @$row.removeClass('discussion-unpublished')
          @$row.addClass('discussion-published')
        else
          @$row.removeClass('discussion-published')
          @$row.addClass('discussion-unpublished')

    # Internal: Add event handlers to the model.
    #
    # Returns nothing.
    attachModel: ->
      @model.on('change:hidden', @hide)
      @model.on('change:published', @renderPublishChange)
