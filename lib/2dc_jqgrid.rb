module Jqgrid

    def jqgrid_stylesheets(theme="default")
      stylesheet_link_tag "jqgrid/themes/#{theme}/jquery-ui-1.8.custom.css",
        'jqgrid/ui.jqgrid.css',
        :cache => "jqgrid-#{theme}-css"
    end

    def jqgrid_javascripts
      locale = I18n.locale rescue :en
      javascript_include_tag "jqgrid/i18n/grid.locale-#{locale}.js",
        'jqgrid/jquery.jqGrid.min.js',
        # Don't know if we need it, if smth not working, just uncomment it
        #'jqgrid/grid.tbltogrid',
        'jqgrid/jquery.contextmenu.r2.packed.js',
        'jqgrid/jquery.cookie.js',
        :cache => 'jqgrid-js'
    end

    def jqgrid(title, id, action, columns = [], options = {})
      
      # Default options
      options = 
        { 
          :rows_per_page       => '10',
          :sort_column         => '',
          :sort_order          => '',
          :height              => '240',
          :gridview            => 'false',
          # If specified will create a handler using the specified
          # string as the name of the error handler function. Default
          # error handling code will be created for this function.
          :error_handler       => 'null',  
          # The other option is to pass in the name of a custom error handler
          # created external to this plugin, to use this do not specify an
          # :error_handler option and specify the name of the custom error 
          # handler using this option.
          :custom_error_handler=> 'null',
          :inline_edit_handler => 'null',         
          :add                 => 'false',
          :delete              => 'false',
          :search              => 'true',
          :edit                => 'false',          
          :view                => 'false',          
          :inline_edit         => 'false',
          :autowidth           => 'false',
          :rownumbers          => 'false',
          :viewrecords         => 'true',
          :rowlist             => '[10,25,50,100]',
          :pagerpos            => 'center',
          :hiddengrid          => 'false',
          :hidegrid            => 'false',
          :shrinkToFit         => 'true',
          :footerrow           => 'false',
          :userDataOnFooter    => 'false',
          :loadonce            => 'false',
          :cellsubmit          => 'remote',
          :cellEdit            => 'false',
	        # If not a *local* search then it depends on DB, postgres for example is case insensitive when using LIKE
          # so it will ignore this, in docs is says:
          # By default the *local* searching is case-sensitive. To make the local search and 
          # sorting not case-insensitive set this options to true
          :ignoreCase	       => 'true',
          :form_width          => 300,
          :loadui              => 'enable',
          :context_menu        => {:menu_bindings => nil, :menu_id => nil},
          # Recreate the edit/add dialogs by default do not cache
          :recreateForm        => 'true',
          :customButtons       => [],
          :before_show_form_edit => 'null',
          :before_show_form_add  => 'null',
          :group_by            => 'null'
        }.merge(options)
      
      # Stringify options values
      options.inject({}) do |options, (key, value)|
        options[key] = (key != :subgrid && key != :context_menu) ? value.to_s : value
        options
      end
      
      edit_button = (options[:edit].to_s == 'true' && options[:inline_edit].to_s == 'false').to_s

      # beforeShowForm handlers
      if options[:before_show_form_edit] == 'null'
        # If no error handlers return true
        options[:before_show_form_edit] = 'true;'
      end
      if options[:before_show_form_add] == 'null'
        # If no error handlers return true
        options[:before_show_form_add] = 'true;'
      end

      # Enable beforeRequest callback
      # Before requesting data, call the Javascript function options[:before_request] (defined by the user)
      before_request = ""
      if options[:before_request].present?
        before_request = %Q/
        beforeRequest: function(){
          #{options[:before_request]}();
        },
        /
      end

      # Enable gridComplete callback
      # When grid completely loaded, call the Javascript function options[:grid_complete] (defined by the user)
      grid_complete = ""
      if options[:grid_complete].present?
        grid_complete = %Q/
        gridComplete: function(){
          #{options[:grid_complete]}();
        },
        /
      end

      # Enable grid_loaded callback
      # When data are loaded into the grid, call the Javascript function options[:grid_loaded] (defined by the user)
      grid_loaded = ""
      if options[:grid_loaded].present?
        grid_loaded = %Q/
        loadComplete: function(){
          #{options[:grid_loaded]}();
        },
        /
      end

      # Check for grouping
      grouping = ''
      grouping_view = ''
      if options[:group_by] != 'null'
        grouping = 'grouping: true,'
        grouping_view = %Q~
          groupingView: {
            groupField: ['#{options[:group_by]}'],
            groupDataSorted: true
          },
        ~
      end

      # Setup error handler if required
      error_handler_code = ''
      error_handler_name = 'null'
      if options[:error_handler] == 'null' && options[:custom_error_handler] == 'null'
        # If no error handlers return true
        options[:error_handler_return_value] = 'true;'
      else
        if options[:error_handler] == "null"
          # Setup custom handler
          error_handler_name = options[:custom_error_handler]
          options[:error_handler_return_value] = options[:custom_error_handler]
        else
          # Construct default error handler code
          error_handler_name = options[:error_handler]    
          options[:error_handler_return_value] = options[:error_handler]
          error_handler_code = %Q/function #{options[:error_handler]}(r, data, action) {
            var resText=JSON.parse(r.responseText);
            if (resText[0]==true) {
              jQuery('#flash_alert').html("<span class='ui-icon ui-icon-info' style='float:left; margin-right:.3em;'><\/span>"+resText[1]);
              jQuery('#flash_alert').slideDown();
              window.setTimeout(function() {
                jQuery('#flash_alert').slideUp();
                }, 3000);
                return [resText[0]]
              }else{
                return [resText[0],resText[1]]
              }
          }/
        end        
      end
      
      # Generate columns data
      col_names, col_model = gen_columns(columns)

      # Enable filtering (by default)
      search = ""
      filter_toolbar = ""
      if options[:search] == 'true'
        search = %Q/.navButtonAdd("##{id}_pager",{caption:"",title:jQuery.jgrid.nav.searchtitle, buttonicon :'ui-icon-search', onClickButton:function(){ mygrid[0].toggleToolbar() } })/
        filter_toolbar = "mygrid.filterToolbar();"
        filter_toolbar << "mygrid[0].toggleToolbar()"
      end

      # Check if we need to add any custom buttons,
      # see http://www.trirand.com/jqgridwiki/doku.php?id=wiki:custom_buttons
      # customButtons should be an array of hashes providing the required options for each button, e.g.
      # To add a separator include the separator option with either 'before' or 'after' as the values
      # [{:caption => '', :title => 'Merge', :buttonicon => 'ui-icon-add', :onClickButton => %Q/ function(){ alert("Adding Row");} /, :position => 'last', :separator => 'before'}]
      custom_buttons = ''
      if options[:customButtons].size > 0 && options[:customButtons].is_a?(Array)
        options[:customButtons].each do |button|
          if button.is_a?(Hash)
            # Check for separator before button
            if button.has_key?(:separator) && button[:separator] == 'before'
              custom_buttons += %Q~.navSeparatorAdd("##{id}_pager")~
            end
            custom_buttons += %Q~.navButtonAdd("##{id}_pager",{~
            button_options = ''
            button.each do |key, value|
              if key != :separator
                button_options += ',' unless button_options.blank?
                if key == :onClickButton
                  button_options += %Q~#{key.to_s}:#{value}~
                else
                  button_options += %Q~#{key.to_s}:'#{value}'~
                end
              end
            end
            custom_buttons += "#{button_options}})"
            # Check for separator after button
            if button.has_key?(:separator) && button[:separator] == 'after'
              custom_buttons += %Q~.navSeparatorAdd("##{id}_pager")~
            end
          end
        end
      end
     
      # Enable sortableRows
      sortableRows=""
      
      # Enable multi-selection (checkboxes)
      multiselect = "multiselect: false,"
      multiselect_handlers = ''
      cookie_array = ''
      if options[:multi_selection]
        multiselect = "multiselect: true,"
        multihandler = %Q/
          jQuery("##{id}_select_button").click(function() { 
            var s; s = jQuery("##{id}").getGridParam('selarrrow'); 
            #{options[:selection_handler]}(s); 
            return false;
          });/
        # Create object to manage cookie array used to store our selections
        cookie_array = %Q~
          var cookieArray = function(cookieName) {
            // When the cookie is saved the items will be a comma separated string
            // so we will split the cookie by comma to get the original array
            // Get the cookie if it exists
            var cookie = jQuery.cookie(cookieName);
            // Load the items or a new array if null.
            var items = cookie ? cookie.split(/,/) : new Array();

            // Return a object that we can use to access the array.
            return {
              "add": function(val) {
                // Add value to the items.
                items.push(val);
              },
              "del": function(val) {
                // Remove value from the items.
                if(jQuery.inArray(val, items) > -1) items.splice(jQuery.inArray(val, items), 1);
              },
              "clear": function() {
                //clear the cookie.
                jQuery.cookie(cookieName, null);
              },
              "save": function() {
                // Save the items to a cookie.
                jQuery.cookie(cookieName, items.join(','));
              },
              "exists": function(val) {
                // Check if value exists in array
                return (jQuery.inArray(val, items) > -1);
              },
              "items": function() {
                // Get all the items.
                return items;
              }
            }
          }
          // Clear cookie if it exists
          var selected_records = new cookieArray("#{id}_selected_records");
          selected_records.clear();
          // Create another cookie to track those records unselected
          var unselected_records = new cookieArray("#{id}_unselected_records");
          unselected_records.clear();
        ~
        # Create handlers to handle selection
        multiselect_onselectrow = %Q~
          // Handles single record selection
          var selected_records = new cookieArray("#{id}_selected_records");
          var unselected_records = new cookieArray("#{id}_unselected_records");
          //alert(selected_records.items());
          if (selected) {
            selected_records.add(ids);
            unselected_records.del(ids);
          } else {
            selected_records.del(ids);
            unselected_records.add(ids);
          }
          // Save the cookie
          selected_records.save();
          unselected_records.save();
          //alert(selected_records.items());
        ~
        multiselect_handlers = %Q~
          // Handle select all
          onSelectAll: function(ids, selected){
            var selected_records = new cookieArray("#{id}_selected_records");
            var unselected_records = new cookieArray("#{id}_unselected_records");
            // Process the ids
            //alert(selected_records.items());
            jQuery.each(ids, function (i, id) {
              if (selected) {
                selected_records.add(id);
                unselected_records.del(id);
              } else {
                selected_records.del(id);
                unselected_records.add(id);
              }
            });
            // Save the cookie
            selected_records.save();
            unselected_records.save();
            //alert(selected_records.items());
          },
          gridComplete: function(){
            // Hide the select all checkbox if required
            #{options[:hide_select_all] ? "jQuery('#cb_#{id}').hide();" : ''}
            // Get cookie
            var selected_records = new cookieArray("#{id}_selected_records");
            // Check if we have selections
            if (selected_records.items().length > 0) {
              var grid = jQuery("##{id}");
              // Process and apply selections
              grid_ids = grid.getDataIDs();
              jQuery.each(grid.getDataIDs(), function (i, id) {
                if (selected_records.exists(id)) {
                  grid.setSelection(id, false);
                }
              });
            }
            #{options[:grid_complete].present? ? "#{options[:grid_complete]}();" : ''}
          },
        ~
        grid_complete = ''
      end

      # Enable master-details, kept for backward compatability, if you want a single or
      # multiple detail grids linked to a master use options[:master_detail_grids]
      masterdetails = ""
      if options[:master_details]
        masterdetails = %Q~
          if(ids == null) {
            ids=0;
            if(jQuery("##{id}_details").getGridParam('records') >0 )
            {
              jQuery("##{id}_details").setGridParam({url:"#{options[:details_url]}?q=1&id="+ids,page:1})
              .setCaption("#{options[:details_caption]}: "+ids)
              .trigger('reloadGrid');
            }
          }
          else
          {
            jQuery("##{id}_details").setGridParam({url:"#{options[:details_url]}?q=1&id="+ids,page:1})
            .setCaption("#{options[:details_caption]} : "+ids)
            .trigger('reloadGrid');
          }
        ~
      end

      # Enable master-details, using this option you can specify any number of detail grids to be linked
      # to a master. To do so you need to use an array of hashes to describe the relationships.
      # For example:
      # :master_detail_grids => [{:grid_id => "timesheet_detail_grid",
      #  :details_url => placement_timesheet_detail_index_path(@placement),
      #  :caption => 'Payroll Detail', :caption_field => 'candidate_code'},
      #  {:grid_id => "timesheet_daily_grid",
      #  :details_url => placement_timesheet_daily_index_path(@placement),
      #  :caption => 'Daily Time/Hours', :caption_field => 'candidate_code'}],
      #
      # You can also specify and edit url via the :edit_url parameter
      #
      # This will setup two grids that will be linked to the master.
      masterdetailgrids = ""
      if options[:master_details_grids] && options[:master_details_grids].size > 0 && options[:master_details_grids].is_a?(Array)
        grid_methods = ""
        options[:master_details_grids].each do |grid|
          if grid.is_a?(Hash)
            grid_methods += %Q~
              caption_value = jQuery('##{id}').jqGrid('getCell', ids, '#{grid[:caption_field]}');
              jQuery("##{grid[:grid_id]}").setGridParam({url:"#{grid[:details_url]}?q=1&id="+ids,page:1})
                .setCaption("#{grid[:caption]}: "+caption_value);
              jQuery("##{grid[:grid_id]}").trigger('reloadGrid');
              ~
            if grid.has_key?(:edit_url)
              grid_methods += %Q~
                jQuery("##{grid[:grid_id]}").setGridParam({editurl:"#{grid[:edit_url]}?parent_id="+ids});
                ~
            end
          end
        end
        unless grid_methods.blank?
          masterdetailgrids = %Q~
            if (ids == null) ids = 0;
            var caption_value;
            #{grid_methods}
          ~
        end
      end

      # Enable selection link, button
      # The javascript function created by the user (options[:selection_handler]) will be called with the selected row id as a parameter
      selection_link = ""
      if options[:direct_selection].blank? && options[:selection_handler].present? && options[:multi_selection].blank?
        selection_link = %Q/
        jQuery("##{id}_select_button").click( function(){ 
          var id = jQuery("##{id}").getGridParam('selrow'); 
          if (id) { 
            #{options[:selection_handler]}(id); 
          } else { 
            alert("Please select a row");
          }
          return false; 
        });/
      end

      dblclick = ""
      # Enable row double-clicking handler
      if  options[:dblclick_handler].present?
        dblclick = %Q/
        ondblClickRow: function(id){ 
          if(id){ 
            #{options[:dblclick_handler]}(id); 
          } 
        },/
      end  

      # Enable inline editing
      # When a row is selected, all fields are transformed to input types
      editable = ""
      if options[:edit].to_s == 'true' && options[:inline_edit].to_s == 'true'
        editable = %Q/
          if(ids && ids!==lastsel){
            jQuery('##{id}').restoreRow(lastsel);
            jQuery('##{id}').editRow(ids, true, #{options[:inline_edit_handler]}, #{error_handler_name});
            lastsel=ids;
          }
        /
      end

      # Enable direct selection (when a row in the table is clicked)
      # The javascript function created by the user (options[:selection_handler]) will be called with the selected row id as a parameter
      direct_link = ""
      if options[:direct_selection] && options[:selection_handler].present?
        direct_link = %Q/
          if(ids){
            #{options[:selection_handler]}(ids);
          }
        /
      end

      # As there may be multiple options requiring the use of the onSelectRow event, we need to include them all
      onselectrow = %Q~
        onSelectRow: function(ids, selected){
          #{multiselect_onselectrow}
          #{masterdetails}
          #{masterdetailgrids}
          #{editable}
          #{direct_link}
        },
      ~

      # Context menu
      # See http://www.trendskitchens.co.nz/jquery/contextmenu/
      # http://www.hard-bit.net/files/jqGrid-3.5/ContextMenu.html
      # http://www.hard-bit.net/blog/?p=171
      #
      context_menu = ""
      if options[:context_menu].size > 0 && !options[:context_menu][:menu_id].blank?
        context_menu = %Q/
        afterInsertRow: function(rowid, rowdata, rowelem){
          jQuery('#' + rowid).contextMenu('#{options[:context_menu][:menu_id]}', #{options[:context_menu][:menu_bindings]});
        },/
      end           
      
      # Enable subgrids
      subgrid = ""
      subgrid_enabled = "subGrid:false,"

      if options[:subgrid].present?
        
        subgrid_enabled = "subGrid:true,"
        
        options[:subgrid] = 
          {
            :rows_per_page => '10',
            :sort_column   => 'id',
            :sort_order    => 'asc',
            :add           => 'false',
            :edit          => 'false',
            :delete        => 'false',
            :search        => 'false',
            :viewrecords   => 'true',
            :rowlist       => '[10,25,50,100]',
            :shrinkToFit   => 'false',
            :form_width    => 300,
            :autowidth     => 'false',
            :footerrow           => 'false',
            :userDataOnFooter    => 'false',
            :context_menu  => {:menu_bindings => nil, :menu_id => nil},
          }.merge(options[:subgrid])

        # Stringify options values
        options[:subgrid].inject({}) do |suboptions, (key, value)|
          suboptions[key] = value.to_s
          suboptions
        end
        
        subgrid_inline_edit = ""
        if options[:subgrid][:inline_edit] == true
          options[:subgrid][:edit] = 'false'
          subgrid_inline_edit = %Q/
          onSelectRow: function(id){ 
            if(id && id!==lastsel){ 
              jQuery('#'+subgrid_table_id).restoreRow(lastsel);
              jQuery('#'+subgrid_table_id).editRow(id,true); 
              lastsel=id; 
            } 
          },
          /
        end
          
        if options[:subgrid][:direct_selection] && options[:subgrid][:selection_handler].present?
          subgrid_direct_link = %Q/
          onSelectRow: function(id){ 
            if(id){ 
              #{options[:subgrid][:selection_handler]}(id); 
            } 
          },
          /
        end     

        # Context menu
        # See http://www.trendskitchens.co.nz/jquery/contextmenu/
        # http://www.hard-bit.net/files/jqGrid-3.5/ContextMenu.html
        # http://www.hard-bit.net/blog/?p=171
        #
        subgrid_context_menu = ""
        if options[:subgrid][:context_menu].size > 0 && !options[:subgrid][:context_menu][:menu_id].blank?
          subgrid_context_menu = %Q/
          afterInsertRow: function(rowid, rowdata, rowelem){
            jQuery('#' + rowid).contextMenu('#{options[:subgrid][:context_menu][:menu_id]}', #{options[:subgrid][:context_menu][:menu_bindings]});
          },/
        end

        sub_col_names, sub_col_model = gen_columns(options[:subgrid][:columns])
        
        subgrid = %Q~
        subGridRowExpanded: function(subgrid_id, row_id) {
        		var subgrid_table_id, pager_id;
        		subgrid_table_id = subgrid_id+"_t";
        		pager_id = "p_"+subgrid_table_id;
        		jQuery("#"+subgrid_id).html("<table id='"+subgrid_table_id+"' class='scroll'></table><div id='"+pager_id+"' class='scroll'></div>");
        		var subgrd = jQuery("#"+subgrid_table_id).jqGrid({
        			url:"#{options[:subgrid][:url]}?q=2&id="+row_id,
                                editurl:'#{options[:subgrid][:edit_url]}?parent_id='+row_id,                            
        			datatype: "json",
        			colNames: #{sub_col_names},
        			colModel: #{sub_col_model},
              rowNum:#{options[:subgrid][:rows_per_page]},
              pager: pager_id,
              imgpath: '/images/jqgrid',
              sortname: '#{options[:subgrid][:sort_column]}',
                  sortorder: '#{options[:subgrid][:sort_order]}',
              viewrecords: #{options[:subgrid][:viewrecords]},
              rowlist: #{options[:subgrid][:rowlist]},
              shrinkToFit: #{options[:subgrid][:shrinkToFit]},
              autowidth: #{options[:subgrid][:autowidth]},
              footerrow: #{options[:subgrid][:footerrow]},
              userDataOnFooter: #{options[:subgrid][:userDataOnFooter]},

              //toolbar : [true,"top"],
              #{subgrid_inline_edit}
              #{subgrid_direct_link}
              #{subgrid_context_menu}
              height: '100%'
        		})
        		.navGrid("#"+pager_id,
              {edit:#{options[:subgrid][:edit]},add:#{options[:subgrid][:add]},del:#{options[:subgrid][:delete]},search:false},
              // Edit options
              // *** Set edit & add forms modal to false, if true then it causes all sorts of problems with datepicker and other issues ***
              {closeOnEscape:true,modal:false,recreateForm:#{options[:recreateForm]},width:#{options[:subgrid][:form_width]},closeAfterEdit:true,afterSubmit:function(r,data){return #{options[:error_handler_return_value]}(r,data,'edit');}},
              // Add options
              {closeOnEscape:true,modal:false,recreateForm:#{options[:recreateForm]},width:#{options[:subgrid][:form_width]},closeAfterAdd:true,afterSubmit:function(r,data){return #{options[:error_handler_return_value]}(r,data,'add');}},
              // Delete options
              {closeOnEscape:true,modal:true,afterSubmit:function(r,data){return #{options[:error_handler_return_value]}(r,data,'delete');}}
            )
            .navButtonAdd("#"+pager_id,{caption:"",title:jQuery.jgrid.nav.searchtitle, buttonicon :'ui-icon-search', onClickButton:function(){ subgrd[0].toggleToolbar() } })
            subgrd.filterToolbar();
            subgrd[0].toggleToolbar();
        	},
        	subGridRowColapsed: function(subgrid_id, row_id) {
        	},
        ~
      end

      # Generate required Javascript & html to create the jqgrid
      %Q(
        <script type="text/javascript">
          #{error_handler_code}
          #{cookie_array}
          var lastsel;
          #{'jQuery(document).ready(function(){' unless options[:omit_ready]=='true'}
          var mygrid = jQuery("##{id}").jqGrid({
              url:'#{action}?q=1',
              editurl:'#{options[:edit_url]}',
              datatype: "json",
              colNames:#{col_names},
              colModel:#{col_model},
              pager: '##{id}_pager',
              pagerpos:'#{options[:pagerpos]}', 
              rowNum:#{options[:rows_per_page]},
              rowList:#{options[:rowlist]},
              imgpath: '/images/jqgrid',
              viewrecords:#{options[:viewrecords]},
              height: '#{options[:height]}',
              #{"sortname: '#{options[:sort_column]}'," unless options[:sort_column].blank?}
              #{"sortorder: '#{options[:sort_order]}'," unless options[:sort_order].blank?}
              gridview: #{options[:gridview]},
              scrollrows: true,
              autowidth: #{options[:autowidth]},
              loadui: '#{options[:loadui]}',
              rownumbers: #{options[:rownumbers]},
              hiddengrid: #{options[:hiddengrid]},
              hidegrid: #{options[:hidegrid]}, 
              shrinkToFit: #{options[:shrinkToFit]}, 
              footerrow: #{options[:footerrow]},
              loadonce: #{options[:loadonce]},
	            ignoreCase: #{options[:ignoreCase]},
              cellsubmit: '#{options[:cellsubmit]}',
              cellEdit: #{options[:cellEdit]},
              userDataOnFooter: #{options[:userDataOnFooter]},
	            subGridOptions: {
		            openicon : "ui-icon-arrowreturn-1-e",
                selectOnExpand : true, 
	            },
              loadError: function(xhr, status, error){
                // Redirect to login page when session expires, see application controller
                if (error == 'Unauthorized') {
                  window.location = '/login';
                } else {
	                alert('An error has occurred during the grid load operation');
		            }
              },
              #{grouping}
              #{grouping_view}
              #{multiselect}
              #{multiselect_handlers}
              #{onselectrow}
              #{grid_loaded}
	      #{dblclick}
              #{before_request}
              #{grid_complete}
              #{context_menu}
              #{subgrid_enabled}
              #{subgrid}
              caption: "#{title}"             
            })
            .navGrid('##{id}_pager',
              {edit:#{edit_button},add:#{options[:add]},del:#{options[:delete]},view:#{options[:view]},search:false,refresh:true},
              // Edit options
              // *** Set edit & add forms modal to false, if true then it causes all sorts of problems with datepicker and other issues ***
              {closeOnEscape:true,modal:false,recreateForm:#{options[:recreateForm]},width:#{options[:form_width]},closeAfterEdit:true,afterSubmit:function(r,data){return #{options[:error_handler_return_value]}(r,data,'edit');},beforeShowForm:function(form){return #{options[:before_show_form_edit]}(form);}},
              // Add options
              {closeOnEscape:true,modal:false,recreateForm:#{options[:recreateForm]},width:#{options[:form_width]},closeAfterAdd:true,afterSubmit:function(r,data){return #{options[:error_handler_return_value]}(r,data,'add');},beforeShowForm:function(form){return #{options[:before_show_form_add]}(form);}},
              // Delete options
              {closeOnEscape:true,modal:true,afterSubmit:function(r,data){return #{options[:error_handler_return_value]}(r,data,'delete');}}
            )
            #{search}
            #{custom_buttons}
            #{multihandler}
            #{selection_link}
            #{filter_toolbar}
          #{'})' unless options[:omit_ready]=='true'};
        </script>
        <div id="flash_alert" style="display:none;padding:0.7em;" class="ui-state-highlight ui-corner-all"></div>
        <table id="#{id}" class="scroll" cellpadding="0" cellspacing="0"></table>
        <div id="#{id}_pager" class="scroll" style="text-align:center;"></div>
      )
    end

    private
    
    def gen_columns(columns)
      # Generate columns data
      col_names = "[" # Labels
      col_model = "[" # Options
      columns.each do |c|
        col_names << "'#{c[:label]}',"
        col_model << "{name:'#{c[:field]}', index:'#{c[:field]}'#{get_attributes(c)}},"
      end
      col_names.chop! << "]"
      col_model.chop! << "]"
      [col_names, col_model]
    end

    # Generate a list of attributes for related column (align:'right', sortable:true, resizable:false, ...)
    def get_attributes(column)
      options = ","
      column.except(:field, :label).each do |couple|
        if couple[0] == :editoptions
          options << "editoptions:#{get_sub_options(couple[1])},"
        elsif couple[0] == :formatoptions
          options << "formatoptions:#{get_sub_options(couple[1])},"        
        elsif couple[0] == :formoptions
          options << "formoptions:#{get_sub_options(couple[1])},"
        elsif couple[0] == :searchoptions
          options << "searchoptions:#{get_sub_options(couple[1])},"
        elsif couple[0] == :editrules
          options << "editrules:#{get_sub_options(couple[1])},"
        else
          if couple[1].class == String
            options << "#{couple[0]}:'#{couple[1]}',"
          else
            options << "#{couple[0]}:#{couple[1]},"
          end
        end
      end
      options.chop!
    end

    # Generate options for editable fields (value, data, width, maxvalue, cols, rows, ...)
    def get_sub_options(editoptions)
      options = "{"
      editoptions.each do |couple|
        if couple[0] == :value # :value => [[1, "Rails"], [2, "Ruby"], [3, "jQuery"]]
          options << %Q/value:"/
          couple[1].each do |v|
            options << "#{v[0]}:#{v[1]};"
          end
          options.chop! << %Q/",/
        elsif couple[0] == :data # :data => [Category.all, :id, :title])
          options << %Q/value:"/
          couple[1].first.each do |obj|
            options << "%s:%s;" % [obj.send(couple[1].second), obj.send(couple[1].third)]
          end
          options.chop! << %Q/",/
        elsif couple[0] == :dataEvents || couple[0] == :dataInit || couple[0] == :custom_func # :dataInit => %Q~{jQuery(element).datepicker({onSelect: getDt(dateText, inst); }})}~
          options << %Q~#{couple[0]}:#{couple[1]},~
        elsif couple[0] == :elmsuffix || couple[0] == :elmpreffix # :elmsuffix => %Q~<a id="companysearch" href="javascript:void(0)"><span id="companysearchicon" class="ui-icon ui-icon-plus" style="position:absolute; top:2px; right:25px;"></span></a>~
          options << %Q~#{couple[0]}:'#{couple[1]}',~
        else # :size => 30, :rows => 5, :maxlength => 20, ...
          if couple[0] == :elmsuffix || couple[1].instance_of?(Fixnum) || couple[1] == 'true' || couple[1] == 'false' || couple[1] == true || couple[1] == false || couple[1] =~ /function/
              options << %Q/#{couple[0]}:#{couple[1]},/
            else
              options << %Q/#{couple[0]}:"#{couple[1]}",/          
          end
        end
      end
      options.chop! << "}"
    end

end


module JqgridJson

  def to_jqgrid_json(attributes, current_page, per_page, total, user_data=nil)
    json = %Q({"page":"#{current_page}","total":#{total/per_page.to_i+1},"records":"#{total}")
    if total > 0
      json << %Q(,"rows":[)
      each do |elem|
        elem.id ||= index(elem)
        # Need to check if this is a composite key, if so we need to
        # remove any meta characters as the generated ID's in the HTML
        # can not contain meta chars, see
        # http://stackoverflow.com/questions/3208876/using-jquery-selector-with-ids-with-comma
        if elem.id.is_a?(Array)
          # Here we convert everything to ASCII code and join with a -
          # To decode we would do the opposite, i.e.
          # ids.split('-').map(&:to_i).each {|c| a+=c.chr}
          ids = elem.id.join(',').split('').map(&:ord).join('-')
        else
          ids = elem.id
        end
        json << %Q({"id":"#{ids}","cell":[)
        couples = elem.attributes.symbolize_keys
        attributes.each do |atr|
          value = get_atr_value(elem, atr, couples)
          if value and value.is_a? String
            value = escape_json(value)
            json << %Q(#{value},)
          else
            json << %Q("#{value}",)
          end
        end
        json.chop! << "]},"
      end
      json.chop! << "]"
      json << user_data_json(user_data)
      json << "}"
    else
      json << user_data_json(user_data)
      json << "}"
    end
    json
  end
  
  private

  def user_data_json(user_data)
    json = ''
    if user_data
      json << %Q(,"userdata":{)
      user_data.each { |k, v| json << %Q("#{k}":"#{v}",) }
      json.chop! << "}"
    end
    json
  end
    
  def escape_json(json)
    if json
      json.to_json
    else
      ''
    end
  end

  def get_atr_value(elem, atr, couples)
    if atr.instance_of?(String) && atr.to_s.include?('.')
      value = get_nested_atr_value(elem, atr.to_s.split('.').reverse) 
    else
      value = couples[atr]
      value = _resolve_value(atr, elem)
     # value = elem.send(atr.to_sym) if value.blank? && elem.respond_to?(atr) # Required for virtual attributes
    end
    value
  end
  def _resolve_value(value, record)
    case value
    when Symbol
      if record.respond_to?(value)
        record.send(value) 
      else 
        value.to_s
      end
    when Proc
      value.call(record)
    else
      value
    end
  end
  def get_nested_atr_value(elem, hierarchy)
    return nil if hierarchy.size == 0
    atr = hierarchy.pop
    raise ArgumentError, "#{atr} doesn't exist on #{elem.inspect}" unless elem.respond_to?(atr)
    nested_elem = elem.send(atr)
    return "" if nested_elem.nil?
    value = get_nested_atr_value(nested_elem, hierarchy)
    value.nil? ? nested_elem : value
  end
end

module JqgridFilter
  def filter_by_conditions(columns)
    conditions = ""
    columns.each do |column|
      conditions << "#{column} LIKE '%#{params[column]}%' AND " unless params[column].nil?
    end
    conditions.chomp("AND ")
  end
end

