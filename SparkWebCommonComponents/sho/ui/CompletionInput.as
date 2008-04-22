/*
 *This file is part of SparkWeb.
 *
 *SparkWeb is free software: you can redistribute it and/or modify
 *it under the terms of the GNU Lesser General Public License as published by
 *the Free Software Foundation, either version 3 of the License, or
 *(at your option) any later version.
 *
 *SparkWeb is distributed in the hope that it will be useful,
 *but WITHOUT ANY WARRANTY; without even the implied warranty of
 *MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *GNU Lesser General Public License for more details.
 *
 *You should have received a copy of the GNU Lesser General Public License
 *along with SparkWeb.  If not, see <http://www.gnu.org/licenses/>.
 */

// sho.ui.CompletionInput v. 0.7
//
// This code is released under the creative commons license. If you use this code, 
// give me attribution if you feel like it. :-)
//
// This code has not been extensively tested, and may have lots and lots of bugs;
// use at your own risk.
//
// v. 0.7 -- fixed issues with depth management. ported to beta 3.
// v. 0.6 -- added keepLocalHistory
// v. 0.5 -- first public release

package sho.ui
{
	import flash.display.DisplayObject;
	import flash.events.*;
	import flash.filters.DropShadowFilter;
	import flash.geom.Point;
	import flash.net.SharedObject;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.ui.Keyboard;
	
	import mx.collections.*;
	import mx.collections.errors.*;
	import mx.controls.List;
	import mx.controls.TextInput;
	import mx.core.Application;
	import mx.core.IFactory;
	import mx.effects.Fade;
	import mx.events.*;
	import mx.managers.PopUpManager;
	
	import sho.core.Func;
	import sho.core.Range;
	import sho.util.ArrayUtil;
	
	/*
	TODO:
	WARNING! this class only works on RosterItemVOs right now. It has been bastardized from its original purpose
	*/
	
	[DefaultProperty(dataProvider)]
	public class CompletionInput extends mx.controls.TextInput 
	{
		// -------- Constants --------
		
		public static const COMPLETION_FAILED		: int = 1;
		public static const COMPLETION_SUCCEEDED	: int = 2;
		public static const COMPLETION_ASYNC		: int = 3;
		
		[Inspectable]
		public function get itemRenderer() : IFactory { return _itemRenderer; }
		public function set itemRenderer(rend:IFactory):void { _itemRenderer = rend; if(completionWidget != null) completionWidget.itemRenderer = rend; }
		private var _itemRenderer:IFactory;

		// -------- Public properties --------
		
		// completionFunction: Function (read/write)
		//
		// A function that is called whenever a completion is requested. 
		//
		// If you don't need this level of control, it may be easier to
		// set the dataProvider with all possible values and let 
		// the control do the filtering for you.
		//
		// A completion function must take the form:
		//		function completion(control: CompletionInput, prefix: String) : int 
		//
		// If the completion failed for any other reason, the function 
		// must return COMPLETION_FAILED.
		// 
		// If the completion succeeds immediately, the function must
		// set the completions array and return COMPLETION_SUCCEEDED.
		//
		// If the completion needs to happen asynchronously, the
		// function must return COMPLETION_ASYNC and then call
		// displayCompletions() once the completions array has
		// been set.
		
		[Inspectable]
		public function get completionFunction() : Function 			{ return _completionFunction }
		public function set completionFunction(value: Function) : void	{ hideCompletions(); _completionFunction = value }
		private var _completionFunction : Function;
		
		// completions: Array (read/write)
		//
		// An array that holds the results of a completion request.
		//
		// This is set by your completionFunction. If this is 
		// null, it is automatically generated by filtering
		// items from the  in the dataProvider.
		//
		[Inspectable]
		public function get completions() : Array 						{ return _completions }
		public function set completions(value: Array) : void			{ hideCompletions(); _completions = value; }
		private var _completions : Array;
		
		// labelField: String (read/write)
		//
		// When used in conjunction with the dataProvider property,
		// this represents the field of the object that should be 
		// displayed to the user.
		//
		[Inspectable]
		public function get labelField() : String						{ return _labelField }
		public function set labelField(value: String) : void 			{ hideCompletions(); _labelField = value;  _onChange(new CollectionEvent(CollectionEvent.COLLECTION_CHANGE)) }
		private var _labelField : String;
		
		// labelFunction: Function (read/write)
		//
		// When used in conjunction with the dataProvider property,
		// this represents a function that returns the text that should 
		// be displayed to the user. The signature of the function is:
		//     function myLabelFunc(obj: Object) : String
		//
		[Inspectable]
		public function get labelFunction() : Function					{ return _labelFunction }
		public function set labelFunction(value: Function) : void 		{ hideCompletions(); _labelFunction = value;  _onChange(new CollectionEvent(CollectionEvent.COLLECTION_CHANGE)) }
		private var _labelFunction : Function;
		
		// mustPick: Boolean (read/write)
		//
		// When true, this forces the control to always hold the
		// value of one of the valid values. This flag can only be
		// used with a dataProvider. If a completionFunction is
		// used instead, seting mustPick to true will have no effect.
		//
		[Inspectable]
		public function get mustPick() : Boolean						{ return _mustPick }
		public function set mustPick(value: Boolean) : void 			{ hideCompletions(); _mustPick = value; }
		private var _mustPick : Boolean = false;
		
		// keepSorted: Boolean (read/write)
		//
		// If true, this causes completions to always be shown
		// in the same order as originally given. If false, the
		// order may be changed for efficiency.
		//
		[Inspectable]
		public function get keepSorted() : Boolean						{ return (keepLocalHistory) ? false : _keepSorted }
		public function set keepSorted(value: Boolean) : void 			{ hideCompletions(); _keepSorted = value; }
		private var _keepSorted : Boolean = false;
		
		// ignoreThe: Boolean (read/write)
		//
		// When true, this allows words beginning with "the" and a
		// single space to match the user's typing. For example, if 
		// the user types "bea", it would be considered a match for
		// the string "The Beatles". This flag can only be
		// used with a dataProvider. If a completionFunction is
		// used instead, seting ignoreThe to true will have no effect.
		//
		[Inspectable]
		public function get ignoreThe() : Boolean						{ return _ignoreThe }
		public function set ignoreThe(value: Boolean) : void 			{ hideCompletions(); _ignoreThe = value; }
		private var _ignoreThe : Boolean = false;
		
		// keepLocalHistory: Boolean (read/write)
		//
		// When true, this causes the control to keep track of the
		// entries that are typed into the control, and saves the
		// history as a local shared object. When true, the 
		// completionFunction and dataProvider are ignored.
		//
		[Inspectable]
		public function get keepLocalHistory() : Boolean				{ return _keepLocalHistory }
		public function set keepLocalHistory(value: Boolean) : void		{ hideCompletions(); _keepLocalHistory = value; }
		private var _keepLocalHistory : Boolean = false;
				
		// historyId: String (read/write)
		//
		// This is the id that should be used when looking up 
		// the form item in the local history list. If no
		// history ID is specified, the id of the form item
		// is used instead.
		//
		[Inspectable]
		public function get historyId() : String						{ return (_historyId != null) ? _historyId : id }
		public function set historyId(value: String) : void				{ hideCompletions(); _historyId = value; }
		private var _historyId : String;

		// selectedItem: Object (read only)
		//
		// Returns the item last selected from the list. This may be
		// out of synch with what the user is currently typing.
		//
		[Inspectable]
		public function get selectedItem() : Object						{ return _selectedItem; }
		private var _selectedItem : Object;
		
		// selectedIndex: Object (read only)
		//
		// Returns the index of the item last selected from the list. 
		// This may be out of synch with what the user is currently typing.
		//
		[Inspectable]
		public function get selectedIndex() : int						{ return _selectedIndex; }
		private var _selectedIndex : int = -1;

		// dataProvider: Object (read/write)
		//
		// Holds all of the possible completions for this text field. 
		// If you set this property, the control will take care of 
		// all the filtering for you. If you would like to control
		// the filtering yourself, you should set completionFunction
		// instead of setting dataProvider.
		//
		[Inspectable]
	    public function get dataProvider():Object
	    {
	        return collection;
	    }
	
		// This code below may look mysterious, but it's essentially what 
		// every control in Flex does to wrap a view around
		// the data provider.
		//
	    public function set dataProvider(value:Object):void
	    {
	        if (collection)
	        {
	            collection.removeEventListener(Event.CHANGE, _onChange);
	        }
	
	        if (value is Array)
	        {
	            collection = new ArrayCollection(value as Array);
	        }
	        else if (value is ICollectionView)
	        {
	            collection = ICollectionView(value);
	        }
	        else if (value is IList)
	        {
	            collection = new ListCollectionView(IList(value));
	        }
			else if (value is XMLList)
			{
				collection = new XMLListCollection(value as XMLList);
			}
	        else
	        {
	            // convert it to an array containing this one item
	            collection = new ArrayCollection([value]);
	        }
	
	        collection.addEventListener(CollectionEvent.COLLECTION_CHANGE, _onCollectionChange);
	
	        var event:CollectionEvent =
				new CollectionEvent(CollectionEvent.COLLECTION_CHANGE);
	        event.kind = CollectionEventKind.RESET;
	        _onCollectionChange(event);
	        dispatchEvent(event);
	    }
	
		// -------- Constructor --------
		
		public function CompletionInput()
		{
			super();
			this.addEventListener("change", _onChange);
			this.addEventListener("focusIn", _onFocusIn);
			this.addEventListener("focusOut", _onFocusOut);
			this.addEventListener("mouseUp", _onMouseUp);
			this.addEventListener("keyDown", _onKeyDown);
			this.addEventListener("creationComplete", _onCreationComplete);
			
			justFocused = false;
		}
		
		// -------- Public methods --------
		
		// Starts the process of showing completions by calling
		// the completion function or looking at the data provider.
		// Usually not called explicitly.
		public function offerCompletions(force: Boolean = false) : void
		{
			var prefix : String = this.text;

			// If (a) the entire text is selected, and (b) this is a "mustPick"
			// control, we offer all completions. This is because "mustPick" 
			// controls always have text in them, and it feels odd to not see
			// the other choices.
			//
			if (this.mustPick && this.selectionBeginIndex == 0 && this.selectionEndIndex == this.text.length)
				prefix = "";
			
			// Do not show completions when no characters have
			// been input yet, unless this is a "must pick" list.
			if (!this.mustPick && this.text.length == 0 && !force)
			{
				hideCompletions();
				return;
			}
			
			var i : int;
			var result : int = COMPLETION_FAILED;
			var itemToSelect : Object = null;
			
			// If this is a "must pick" list, then the first item
			// is always selected by default. Otherwise, the user
			// must explicitly pick one.
			var indexToSelect : int = (mustPick) ? 0 : -1;
			
			var keepGoing : Boolean;
			
//			var start = (new Date()).time;
		
			do
			{
				keepGoing = false;
				
				generateSortedCandidates();
				
				if (_completionFunction != null)
				{
					result = _completionFunction(this, prefix);
				}
				else if (sortedCandidates != null)
				{
					var getLabel : Function = function(obj:*) : Object { return obj.displayName; }
					var searchFunction : Function = Func.combine1of2(ArrayUtil.prefixCompareNoCase, getLabel);
					
					var range : Range = ArrayUtil.binarySearchForRange(sortedCandidates, prefix, searchFunction);
		
					_completions = new Array();
					if (range != null)
					{
						// Fill the completion array.
						_completions.length = (range.hi - range.lo + 1);
	
						for (i = range.lo; i <= range.hi; i++)
						{
							_completions[i-range.lo] = sortedCandidates[i];
						}
					}

					if (_completions.length > 0)
					{
						// If the prefix is not the whole text, we need to search for the whole text
						// in order to select it.
						if (prefix != this.text)
						{
							var range2 : Range = ArrayUtil.binarySearchForRange(_completions, this.text, searchFunction );
							if (range2 != null)
							{
								indexToSelect = range2.lo;
								itemToSelect = _completions[range2.lo];
							}
						}
					}
					
					// if the "ignoreThe" flag is on, search again for the same thing,
					// but starting with the word "the"
					if (_ignoreThe && prefix.length > 0)
					{
						var prefixWithThe : String = "the " + prefix;
						var range2 : Range = ArrayUtil.binarySearchForRange(sortedCandidates, prefixWithThe, searchFunction );
						
						if (range2 != null)
						{
							for (i = range2.lo; i <= range2.hi; i++)
							{
								_completions.push(sortedCandidates[i]);
							}
						}
					}
					
					if (_completions.length > 0)
					{
						if (keepSorted)
						{
							// Sort the array back to its original order.
							_completions.sortOn("index", Array.NUMERIC);
							
							if (itemToSelect != null)
							{
								// Re-evaluate the "indexToSelect" variable given the new sort order.
								indexToSelect = ArrayUtil.binarySearchOn(_completions, itemToSelect.index, "index");
							}
						}
						
						result = COMPLETION_SUCCEEDED;
					}
				}				
				// if "must pick" is true, we keep looping until we find a completion, or
				// until we run into a situation with no possible completions.
				if (_mustPick)
				{
					if (result == COMPLETION_FAILED)
					{
						if (prefix.length > 0)
						{
							// Chop one letter off the prefix for the next time around
							// this loop.
							prefix = prefix.substring(0, prefix.length-1);
							
							// Reset the contents of this field to be the shortened prefix.
							this.text = prefix;
							
							keepGoing = true;
						}
					}
				}
						
				
			} while (keepGoing);
			
//			var diff = (new Date()).time - start;
//			trace("completion took " + diff + "ms");

			if (result == COMPLETION_SUCCEEDED)
			{
				displayCompletions(indexToSelect);
			}
			else
			{
				hideCompletions();
			}
		}	
	
		// Displays the completions to the user. You will typically only
		// need to call this explicitly in the case of asynchronous
		// completion functions. Be sure to set the completions array
		// before calling this.
		public function displayCompletions(indexToSelect: int = 0) : void
		{
			if (parent == null)
				return;
				
			if (_completions != null && _completions.length > 0)
			{
				completionWidget.dataProvider = _completions;
				
				var point : Point = new Point(0, 0);
				
				point = this.localToGlobal(point);
				
				completionWidget.x = point.x;
				completionWidget.y = point.y + this.height;
				completionWidget.width = this.width;
				
				completionWidget.height = Math.min(numVisibleCompletions, _completions.length) * completionWidget.rowHeight;
		
		
				if (indexToSelect >= 0 && indexToSelect < _completions.length)
				{
					// BUG: not sure why I need this callLater, but I do.
					callLater(
						function() : void { 
							completionWidget.selectedIndex = indexToSelect;
							keepSelectionVisible();
						}
					);
				}

				keepSelectionVisible();
					

				// Try to move the widget topmost before displaying.
				completionWidget.parent.setChildIndex(completionWidget, completionWidget.parent.numChildren-1);
				completionWidget.visible = true;
			}
			else
			{
				hideCompletions();
			}
		}
		
		// Hides the completions from the user. You will typically not
		// need to call this explicitly.
		public function hideCompletions() : void
		{
			// If "must pick" is on, hiding and accepting are identical. This makes sure
			// that the text field has a valid value when we dismiss it.
			if (_mustPick)
			{
				acceptCompletion();
			}	
			else if (completionWidget != null)
			{
				completionWidget.visible = false;
			}
		}
	
		// Hides the completions from the user and populates the text field
		// with the selected item from the completion list. You will typically not
		// need to call this explicitly.
		public function acceptCompletion() : void
		{
			if (completionWidget != null)
			{
				if (completionWidget.selectedIndex >= 0)
				{
					// Set the text of the text field to the selected item.
					var index : int = completionWidget.selectedIndex;
					var newText : String;
					
					if (_completions[index] is String)
					{
						newText = _completions[index];
						_selectedItem = _completions[index];
						_selectedIndex = -1;
					}
					else
					{
						newText = _completions[index].label;
						_selectedItem = _completions[index].item;
						_selectedIndex = _completions[index].index;
					}
						
					this.text = newText;
					
					// Set the selection to the end of the text. As it turns out, we
					// need to use call later to do this after Flex tries to set the selection.
	
					this.callLater(function() : void { setSelection(text.length, text.length) } );
				}
							
				// Hide the hints.
				completionWidget.visible = false;
			}
		}	
		
		// -------- Private event handlers --------
		
		// Whenever the model changes, we recreate the list of
		// sorted candidates.
		private function _onCollectionChange(event: Event) : void
		{
			sortedCandidatesDirty = true;
			if(completionWidget.visible)
				offerCompletions();
		}

		private function _onChange(event: Event) : void
		{
			offerCompletions();
		}
		
		private function _onFocusIn(event: Event) : void
		{
			justFocused = true;
			if (mustPick)
				offerCompletions();
		}
		
		private function _onFocusOut(event: Event) : void
		{
			justFocused = false;
			hideCompletions();
			
			if (keepLocalHistory)
				addToLocalHistory();
		}
		
		private function _onMouseUp(event: Event) : void
		{
			if (justFocused && this.selectionBeginIndex == this.selectionEndIndex)
			{
				this.callLater(function() : void { setSelection(0, text.length) });
			}
			justFocused = false;
		}
		
		private function _onKeyDown(event: KeyboardEvent) : void
		{
			justFocused = false;
			if (completionWidget.visible)
			{
				switch (event.keyCode)
				{
				case Keyboard.UP:
				case Keyboard.DOWN:
				case Keyboard.END:
				case Keyboard.HOME:
				case Keyboard.PAGE_UP:
				case Keyboard.PAGE_DOWN:
					moveSelection(event.keyCode);
					break;
				case Keyboard.ENTER:
					acceptCompletion();
					break;
				case Keyboard.TAB:
					hideCompletions();
				    break;
				case Keyboard.ESCAPE:
					hideCompletions();
				    break;
				}
			}
		}
	
		private function _onCreationComplete(event: Event) : void
		{
			completionWidget = PopUpManager.createPopUp(DisplayObject(Application.application), List, false) as List;
			
			if(itemRenderer != null)
				completionWidget.itemRenderer = itemRenderer;
			completionWidget.verticalScrollPolicy = "off";
			completionWidget.labelField = "label";
			completionWidget.addEventListener("itemClick", _onWidgetItemClick);
			completionWidget.visible = false;
			
			if (keepLocalHistory)
			{
				completionWidget.contextMenu = makeWidgetContextMenu();
				completionWidget.addEventListener(ListEvent.ITEM_ROLL_OVER, _onWidgetItemRollover);
			}			
			
			var fade : Fade = new Fade();
			fade.duration = 150;

			completionWidget.setStyle("showEffect", fade);
			completionWidget.setStyle("hideEffect", fade);

			var dropShadow : DropShadowFilter = new DropShadowFilter();
			dropShadow.alpha = 0.25;
			
			completionWidget.filters = [dropShadow];
			
			// This is required in order to populate the field with 
			// a value in the case where "mustPick" is true. This
			// is done inside of a callLater so that other initialization
			// code can run before the candidate list is generated.
			callLater(function() : void { generateSortedCandidates() });
		}
		
		private function _onWidgetItemClick(event: Event) : void
		{
			acceptCompletion();
			event.stopPropagation();
		}

		private function _onWidgetItemRollover(event: ListEvent) : void
		{
			lastWidgetRollOverItem = event.rowIndex;
		}
		
		// -------- Private methods --------
		
		// Generates a sorted candidate list from the data provider, if
		// any. Sorting the list is important, because it allows us to 
		// quickly search for completions. 
		//
		private function generateSortedCandidates() : void
		{
			if (!sortedCandidatesDirty)
				return;
			
			sortedCandidatesDirty = false;

			// If we are going off of local history, the data
			// comes from local shared objects.
			if (keepLocalHistory)
			{
				collection = null;
				
				var controlId : String = historyId;
				if (controlId != null)
				{
					var so:SharedObject = SharedObject.getLocal("formData");
		
					dataProvider = so.data[controlId];
				}
			}
			
			if (collection == null)
			{
				sortedCandidates = null;
				return;
			}

			// Create a mapping function that (a) gets the label from the
			// item and (b) stashes it onto an object along with the original
			// item and the original index.
			//
			var mapFunc : Function;
			var index : int = 0;
		/*	
			if (_labelFunction != null)
			{
				mapFunc = function(obj: Object) : Object { return { item: obj, label: _labelFunction(obj), index: index++ } }
			}
			else if (_labelField != null) 
			{
				mapFunc = function(obj: Object) : Object { return { item: obj, label: obj[_labelField], index: index++ } }
			}
			else
			{
				mapFunc = function(obj: Object) : Object { return { item: obj, label: obj as String, index: index++} };
			}*/
			mapFunc = function(obj:Object) : Object { return obj; };

//			var start : int;
//			var diff : int;

//			start = (new Date()).time;

			// Call the mapping function on each item in the .
			sortedCandidates = Func.mapCollection(collection, mapFunc);

//			diff = (new Date()).time - start;
//			trace("map took " + diff + "ms");

			// If "must pick" is on, we populate the text input field
			// with the first item in the list.	
			var defaultString : String;		
			if (_mustPick)
			{
				if (sortedCandidates.length > 0)
				{
					_selectedItem = sortedCandidates[0].item;
					defaultString = sortedCandidates[0].label;
					_selectedIndex = sortedCandidates[0].index;
				}
			}
			
			// Sort the array. Ideally, we would use a sort that is fast for arrays 
			// that are already sorted, which will be common. Unfortunately, the
			// standard sort does not appear to be super fast for sorted arrays,
			// and there is no super fast way to tell if the array is already sorted.

//			start = (new Date()).time;
			sortedCandidates.sortOn("displayName", Array.CASEINSENSITIVE);
			
//			diff = (new Date()).time - start;
//			trace("candidate sort took " + diff + "ms");
			
			// Set the text if needed.
			if (_mustPick)
			{
				this.text = defaultString;
			}
		}
		
		private function moveSelection(keyCode : int) : void
		{
			var index : int = completionWidget.selectedIndex;
			if (index < 0)
				index = 0;
			
			switch (keyCode)
			{
			case Keyboard.UP:
				if (index > 0)
					index--;
				break;
	
			case Keyboard.DOWN:
				if (index < _completions.length-1)
					index++;
				break;
	
			case Keyboard.PAGE_UP:
				index = completionWidget.verticalScrollPosition - numVisibleCompletions;
				if (index < 0)
					index = 0;
				break;
	
			case Keyboard.PAGE_DOWN:
				index = completionWidget.verticalScrollPosition + numVisibleCompletions;
				if (index > _completions.length-1)
					index = _completions.length-1;
				break;
			
			case Keyboard.HOME:
				index = 0;
				break;
	
			case Keyboard.END:
				index = _completions.length-1;
				break;
			}
							
			completionWidget.selectedIndex = index;
			keepSelectionVisible();
		}
		
		private function keepSelectionVisible() : void
		{
			if (completionWidget != null && completionWidget.selectedIndex >= 0)
			{
				var first : int = completionWidget.verticalScrollPosition;
				var index : int = completionWidget.selectedIndex;
				
				if (index < first || index >= first + numVisibleCompletions)
				{
					completionWidget.verticalScrollPosition = Math.min(completionWidget.selectedIndex, completionWidget.maxVerticalScrollPosition);
				}
			}
		}
		
		private function makeWidgetContextMenu() : ContextMenu
		{
            var widgetMenu : ContextMenu = new ContextMenu();
            widgetMenu.hideBuiltInItems();
            
            var item:ContextMenuItem = new ContextMenuItem("Remove from history");
            widgetMenu.customItems.push(item);
            item.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, onRemoveHistoryItem);
            
            item = new ContextMenuItem("Clear history for this field");
            widgetMenu.customItems.push(item);
            item.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, onRemoveAllHistoryForField);
            
            item = new ContextMenuItem("Clear history for this entire application");
            widgetMenu.customItems.push(item);
            item.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, onRemoveAllHistoryForApp);
            
            return widgetMenu;
        }


        private function onRemoveHistoryItem(event:ContextMenuEvent):void 
        {
        	if (keepLocalHistory)
        	{
				var so:SharedObject = SharedObject.getLocal("formData");
	
				var savedData : Array = so.data[id];
				if (savedData != null)
				{					
	        		var obj : Object = completionWidget.dataProvider.getItemAt(lastWidgetRollOverItem);

					var foundIndex : int = ArrayUtil.binarySearch(savedData, obj.label as String);
					if (foundIndex != -1)
					{
						savedData.splice(foundIndex, 1);
						so.flush();
						sortedCandidatesDirty = true;
					}
				}
				
				// Re-show completions.
				offerCompletions();
        	}
        }

		private function onRemoveAllHistoryForField(event:ContextMenuEvent):void 
        {
        	if (keepLocalHistory)
        	{
				var so:SharedObject = SharedObject.getLocal("formData");
				so.data[id] = null;	
				so.flush();
				sortedCandidatesDirty = true;

				// Now that all the data is gone, we should hide completions.
				hideCompletions();
        	}
        }

		private function onRemoveAllHistoryForApp(event:ContextMenuEvent):void 
        {
        	if (keepLocalHistory)
        	{
				var so:SharedObject = SharedObject.getLocal("formData");
				
				for (var key : String in so.data)
				{
					so.data[key] = null;
				}

				so.flush();
				sortedCandidatesDirty = true;

				// Now that all the data is gone, we should hide completions.
				hideCompletions();
        	}
        }

		private function addToLocalHistory() : void
		{
			if (id != null && id != "")
			{
				if (this.text != null && this.text != "")
				{
					var so:SharedObject = SharedObject.getLocal("formData");
		
					var savedData : Array = so.data[id];
					if (savedData == null)
						savedData = so.data[id] = new Array();
					
					if (ArrayUtil.binarySearch(savedData, this.text) == -1)
					{
						ArrayUtil.addSorted(savedData, this.text);
						so.flush();
						sortedCandidatesDirty = true;
					}
				}
			}
		}
		
		// -------- Private variables --------
		
		private var justFocused : Boolean;
		private var completionWidget : List;
		private var sortedCandidates : Array;
		private var sortedCandidatesDirty : Boolean = true;
		private var numVisibleCompletions : int = 8;
	    private var collection : ICollectionView;
	    private var lastWidgetRollOverItem : int;
	}
}