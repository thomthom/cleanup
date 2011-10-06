#-----------------------------------------------------------------------------
# Compatible: SketchUp 7.1+
#             (other versions untested)
#-----------------------------------------------------------------------------
#
# SketchUp versions prior to SketchUp 7.1 are highly prone to loss of geometry.
# Users are advised to not use this plugin unless they run 7.1 or higher.
#
#-----------------------------------------------------------------------------
#
# FEATURES
#
# * Fixes duplicate component definition names ( When in model scope )
# * Purge unused items
# * Erase hidden geometry
# * Erase duplicate faces
# * Erase stray edges ( Except edges on cut plane )
# * Remove edge material
# * Repair split edges
# * Smooth & soft edges
# * Put edges and faces to Layer0
# * Merge identical materials
# * Merge connected co-planar faces
#
#-----------------------------------------------------------------------------
#
# CHANGELOG
#
# 3.1.9 - 06.10.2011
#    * Added: LibFredo Updater support
#
# 3.1.8 - 04.10.2011
#    * Fixed: Incorrect material removal for SketchUp older than version 8.
#
# 3.1.7 - 12.09.2011
#    * Fixed: Incorrect material comparison for textured materials with the same colour
#
# 3.1.6 - 06.09.2011
#    * Fixed: Updated requirement of TT_Lib to 2.5.5.
#
# 3.1.5 - 04.09.2011
#    * Fixed: Reusing Inputbox as they never garbage collect.
#
# 3.1.4 - 16.05.2011
#    * Added error detection for merge faces.
#    * Added validation for merge faces to avoid geometry loss.
#    * Added result feedback to Ruby Console for each standalone operation.
#    * Fixed namespace compatibility with TT_Lib 2.5.4
#    * Fixed merge similar material but - now compare alpha
#    * Changed "Lonely Edges" to "Stray Edges"
#
# 3.1.3 - 10.02.2011
#		 * Fixed bug in remove material workaround for < SU8M1
#		 * Updated TT_Lib2 dependancy to 2.5.3.
#
# 3.1.2 - 09.02.2011
#		 * Fixed missing operation wrappers.
#		 * Fixed merge materials.
#
# 3.1.1 - 09.02.2011
#		 * Fixed bug in the scope selection.
#
# 3.1.0 - 08.02.2011
#		 * Added menus for each cleanup sub-routine.
#
# 3.0.0 - 01.02.2011
#		 * Version 3
#
#-----------------------------------------------------------------------------
#
# TODO
#
# * Detect Materials not in Material list
# * Merge Styles
# * Detect small faces
#
#-----------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-----------------------------------------------------------------------------

require 'sketchup.rb'
require 'TT_Lib2/core.rb'

TT::Lib.compatible?('2.5.8', 'CleanUp³')

#-----------------------------------------------------------------------------


module TT::Plugins::CleanUp
  
  ### CONSTANTS ### --------------------------------------------------------
  
  PLUGIN_NAME     = 'CleanUpÂ³'.freeze # CleanUp³ (UNICODE)
  PLUGIN_VERSION  = '3.1.9'.freeze
  PLUGIN_AUTHOR   = 'thomthom'.freeze
  
  PREF_KEY = 'TT_CleanUp'.freeze
  
  SCOPE_MODEL = 'Model'.freeze
  SCOPE_LOCAL = 'Local'.freeze
  SCOPE_SELECTED = 'Selected'.freeze
  
  GROUND_PLANE = [ ORIGIN, Z_AXIS ]
  
  CONTROLS = {
    :scope => {
      :key     => :scope,
      :label   => 'Scope',
      :value   => SCOPE_MODEL,
      :no_save => true,
      :options => [SCOPE_MODEL, SCOPE_LOCAL, SCOPE_SELECTED],
      :type    => TT::GUI::Inputbox::CT_RADIOBOX,
      :group   => 'General'
    },
    
    :validate => {
      :key   => :validate,
      :label => 'Validate Results',
      :tooltip => <<EOT,
Recommended!
(Windows only. OSX users should run Fix Problems manually.)

Runs SketchUp's validation tool after cleaning the model to ensure a healthy model.
EOT
      :value => true,
      :group => 'General'
    },
    
    :statistics => {
      :key   => :statistics,
      :label => 'Show Statistics',
      :tooltip => <<EOT,
Shows a summary of what was done at the end of the cleanup.
EOT
      :value => true,
      :group => 'General'
    },
    
    :purge => {
      :key   => :purge,
      :label => 'Purge Unused',
      :tooltip => <<EOT,
Purges all unused items in model. (Components, Materials, Styles, Layers)
EOT
      :value => true,
      :group => 'Optimisations'
    },
    
    :erase_hidden => {
      :key   => :erase_hidden,
      :label => 'Erase Hidden Geometry',
      :tooltip => <<EOT,
Erases all hidden entities in the current scope.
EOT
      :value => false,
      :group => 'Optimisations'
    },
    
    :remove_duplicate_faces => {
      :key   => :remove_duplicate_faces,
      :label => 'Erase Duplicate Faces',
      :tooltip => <<EOT,
Warning: Very slow!

Tries to detect faces occupying the same space. Only use if you need to correct models with overlapping faces.
EOT
      :value => false,
      :group => 'Optimisations'
    },
    
    :geom_to_layer0 => {
      :key   => :geom_to_layer0,
      :label => 'Geometry to Layer0',
      :tooltip => <<EOT,
Puts all edges and faces on Layer0.
EOT
      :value => false,
      :group => 'Layers'
    },
    
    :merge_materials => {
      :key   => :merge_materials,
      :label => 'Merge Identical Materials',
      :tooltip => <<EOT,
Note: Processes all materials in the model, not just the current scope!

Merges all identical materials in the model, ignoring metadata attributes.
EOT
      :value => false,
      :group => 'Materials'
    },
    
    :merge_ignore_attributes => {
      :key   => :merge_ignore_attributes,
      :label => 'Ignore Attributes',
      :tooltip => <<EOT,
When checked, attribute meta data is ignored. (Might include render engine data.)
EOT
      :value => true,
      :group => 'Materials'
    },
    
    :merge_faces => {
      :key   => :merge_faces,
      :label => 'Merge Coplanar Faces',
      :tooltip => <<EOT,
Removes edges separating coplanar faces.
EOT
      :value => true,
      :group => 'Coplanar Faces'
    },
    
    :merge_ignore_normals => {
      :key   => :merge_ignore_normals,
      :label => 'Ignore Normals',
      :tooltip => <<EOT,
When checked, faces are considered coplanar even if they are facing the opposite direction to each other.
EOT
      :value => false,
      :group => 'Coplanar Faces'
    },
    
    :merge_ignore_materials => {
      :key   => :merge_ignore_materials,
      :label => 'Ignore Materials',
      :tooltip => <<EOT,
When checked, faces are merged even though their material is different.
EOT
      :value => false,
      :group => 'Coplanar Faces'
    },
    
    :merge_ignore_uv => {
      :key   => :merge_ignore_uv,
      :label => 'Ignore UV',
      :tooltip => <<EOT,
When checked, faces are merged even though their UV mapping is different.
EOT
      :value => true,
      :group => 'Coplanar Faces'
    },
    
    # http://forums.sketchucation.com/viewtopic.php?f=323&t=33473&hilit=cleanup
    #i.add_control( {
    #  :key   => :repair_small_faces,
    #  :label => 'Repair Small Faces',
    #  :value => false,
    #  :group => 'Faces'
    #}
    
    :repair_split_edges => {
      :key   => :repair_split_edges,
      :label => 'Repair Split Edges',
      :value => true,
      :group => 'Edges'
    },
    
    :remove_lonely_edges => {
      :key   => :remove_lonely_edges,
      :label => 'Erase Stray Edges',
      :tooltip => <<EOT,
Removes all edges not connected to any face.
EOT
      :value => true,
      :group => 'Edges'
    },
    
    :remove_edge_materials => {
      :key   => :remove_edge_materials,
      :label => 'Remove Edge Materials',
      :value => false,
      :group => 'Edges'
    },
    
    :smooth_angle => {
      :key   => :smooth_angle,
      :label => 'Smooth Edges by Angle',
      :value => 0.0,
      :group => 'Edges'
    }
  }
  
  
  ### LIB FREDO UPDATER ### ----------------------------------------------------
  
  def self.register_plugin_for_LibFredo6
    {   
      :name => PLUGIN_NAME,
      :author => PLUGIN_AUTHOR,
      :version => PLUGIN_VERSION.to_s,
      :date => '06 Oct 11',   
      :description => 'Offers many cleanup operations for the model.',
      :link_info => 'http://forums.sketchucation.com/viewtopic.php?f=323&t=22920'
    }
  end
  
  
  ### MENU & TOOLBARS ### --------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    m = TT.menu('Plugins').add_submenu( PLUGIN_NAME )
    m.add_item('Clean…')                    { self.show_cleanup_ui }
    m.add_item('Clean with Last Settings')  { self.cleanup_last }
    m.add_separator
    m.add_item('Erase Hidden Geometry')     { self.cu_erase_hidden }
    m.add_item('Erase Stray Edges')         { self.cu_erase_lonely_edges }
    m.add_item('Geometry to Layer0')        { self.cu_geom2layer0 }
    m.add_item('Merge Faces')               { self.cu_merge_faces }
    m.add_item('Merge Materials')           { self.cu_merge_materials }
    m.add_item('Repair Edges')              { self.cu_repair_edges }
  end
  
  
  ### MAIN SCRIPT ### ------------------------------------------------------
 
  
  # @since 3.1.0
  def self.cleanup_last
    options = self.last_options
    options[:scope] = self.current_scope
    
    self.cleanup!( options )
  end
  
  
  # @since 3.1.0
  def self.last_options
    settings = TT::Settings.new( PREF_KEY )
    options = {}
    for key, control in CONTROLS
      options[key] = settings[ control[:label], control[:value] ]
    end
    options
  end
  
  
  # @since 3.1.0
  def self.current_scope
    model = Sketchup.active_model
    if model.selection.empty?
      if model.active_path.nil?
        scope = SCOPE_MODEL
      else
        scope = SCOPE_LOCAL
      end
    else
      scope = SCOPE_SELECTED
    end
    scope
  end
  
  
  # @since 3.1.0
  def self.cu_erase_hidden
    TT::Model.start_operation('Erase Hidden Geometry')
    count = self.erase_hidden( Sketchup.active_model, self.current_scope )
    puts "#{count} hidden entities erased"
    Sketchup.active_model.commit_operation
  end
  
  
  # @since 3.1.0
  def self.cu_geom2layer0
    model = Sketchup.active_model
    scope = self.current_scope
    options = { :geom_to_layer0 => true }
    total_entities = self.count_scope_entity( scope, model )
    progress = TT::Progressbar.new( total_entities, 'Geometry to Layer0' )
    TT::Model.start_operation('Geometry to Layer0')
    count = self.each_entity_in_scope( scope, model ) { |e|
      progress.next
      self.post_process(e, options)
    }
    puts "#{count} entities moved to Layer0"
    model.commit_operation
  end
  
  
  # @since 3.1.0
  def self.cu_erase_lonely_edges
    model = Sketchup.active_model
    scope = self.current_scope
    total_entities = self.count_scope_entity( scope, model )
    progress = TT::Progressbar.new( total_entities, 'Removing stray edges' )
    TT::Model.start_operation('Remove stray edges')
    count = self.each_entities_in_scope( scope, model ) { |entities|
      self.erase_lonely_edges(entities, progress)
    }
    puts "#{count} stray edges erased"
    model.commit_operation
  end
    
    
  # @since 3.1.0
  def self.cu_merge_materials
    TT::Model.start_operation('Merge Materials')
    count = self.merge_similar_materials( Sketchup.active_model, self.last_options )
    puts "#{count} materials merged"
    Sketchup.active_model.commit_operation
  end
    
    
  # @since 3.1.0
  def self.cu_merge_faces
    model = Sketchup.active_model
    scope = self.current_scope
    options = self.last_options
    total_entities = self.count_scope_entity( scope, model )
    progress = TT::Progressbar.new( total_entities , 'Merging Faces' )
    TT::Model.start_operation('Merge Faces')
    errors = []
    count = self.each_entity_in_scope( scope, model ) { |e|
      progress.next
      begin
        self.merge_connected_faces(e, options)
      rescue SketchUpFaceMergeError => e
        errors << e
      end
    }
    puts "#{count} faces merged"
    model.commit_operation
    self.report_errors( errors )
  end
  
  
  # @since 3.1.4
  def self.report_errors( errors )
    return if errors.empty?
    
    # Sort errors by type
    sorted_errors = {}
    errors.each { |error|
      sorted_errors[ error.class ] ||= []
      sorted_errors[ error.class ] << error
    }
    
    # Compile error summary
    formatted_errors = ''
    sorted_errors.each { |type,errors|
      count = errors.size
      message = errors.first
      formatted_errors += "> #{count} - #{message}\n"
    }
    
    # Output errors
    message = "#{errors.size} errors occurred. Please report the error and sample model to the author.\n#{formatted_errors}\n"
    puts message
    UI.messagebox( message, MB_MULTILINE )
  end
    
    
  # @since 3.1.0
  def self.cu_repair_edges
    model = Sketchup.active_model
    scope = self.current_scope
    total_entities = self.count_scope_entity( scope, model )
    progress = TT::Progressbar.new( total_entities, 'Repairing split edges' )
    TT::Model.start_operation('Repair Split Edges')
    count = self.each_entities_in_scope( scope, model ) { |entities|
      TT::Edges.repair_splits( entities, progress )
    }
    puts "#{count} edges repaired"
    model.commit_operation
  end
  
  
  # @since 3.0.0
  def self.show_cleanup_ui
    model = Sketchup.active_model
    
    # Default value for Scope
    if model.selection.empty?
      if model.active_path.nil?
        default_scope = SCOPE_MODEL
      else
        default_scope = SCOPE_LOCAL
      end
    else
      default_scope = SCOPE_SELECTED
    end
    
    self.build_cleanup_ui
    @inputbox.controls[0][:value] = default_scope
    @inputbox.prompt { |results|
      self.cleanup!(results) unless results.nil?
    }
  end
  
  
  # @since 3.1.5
  def self.build_cleanup_ui
    # (i) This is because the inputbox is not GC'd. Probably should find the
    #     cause of that as this method makes CleanUp not work in multiple
    #     active windows in OSX.
    
    return @inputbox if @inputbox
    
    window_options = {
      :title => 'CleanUp³',
      :pref_key => PREF_KEY,
      :modal => true,
      :accept_label => 'CleanUp',
      :cancel_label => 'Cancel',
      :align => 0.3,
      :left => 200,
      :top => 100,
      :width => 290,
      :height => 785
    }
    i = TT::GUI::Inputbox.new(window_options)

    i.add_control( CONTROLS[:scope] )
    i.add_control( CONTROLS[:validate] )
    i.add_control( CONTROLS[:statistics] )
    i.add_control( CONTROLS[:purge] )
    i.add_control( CONTROLS[:erase_hidden] )
    i.add_control( CONTROLS[:remove_duplicate_faces] )
    i.add_control( CONTROLS[:geom_to_layer0] )
    i.add_control( CONTROLS[:merge_materials] )
    i.add_control( CONTROLS[:merge_ignore_attributes] )
    i.add_control( CONTROLS[:merge_faces] )
    i.add_control( CONTROLS[:merge_ignore_normals] )
    i.add_control( CONTROLS[:merge_ignore_materials] )
    i.add_control( CONTROLS[:merge_ignore_uv] )
    i.add_control( CONTROLS[:repair_split_edges] )
    i.add_control( CONTROLS[:remove_lonely_edges] )
    i.add_control( CONTROLS[:remove_edge_materials] )
    i.add_control( CONTROLS[:smooth_angle] )
    
    @inputbox = i
  end
  
  
  # The order which the various cleanup process is important to ensure optimal
  # cleanup and decent performance.
  def self.cleanup!(options)
    # <debug>
    #options.each { |k,v| puts "#{k.to_s.ljust(25)} #{v}" }
    # </debug>
    
    # Warn users of SketchUp older than 7.1
    msg = 'Sketchup prior to 7.1 has a bug which might lead to loss of geometry. Do you want to continue?'
    if not TT::SketchUp.newer_than?(7, 1, 0)
      return if UI.messagebox( msg, MB_YESNO ) == 7 # No
    end
    
    model = Sketchup.active_model
    TT::Model.start_operation('Cleanup Model')
    
    scope = options[:scope]
    
    # Keep statistics of the cleanup.
    stats = {}
    stats['Total Elapsed Time'] = Time.now
    
    # Keep track of errors generated while cleaning.
    errors = []
    
    # Ensure no material is active, as that would prevent the model from being
    # removed from the model.
    model.materials.current = nil
    
    ### Erase Hidden ###
    if options[:erase_hidden]
      stats['Hidden Entities Erased'] = self.erase_hidden( model, scope )
    end
    
    ### Purge ###
    # Purge unused geometry before processing anything else.
    if options[:purge]
      stats['Purged Components'] = model.definitions.length
      Sketchup.status_text = 'Purging Components...'
      model.definitions.purge_unused
      stats['Purged Components'] -= model.definitions.length
    end
    
    ### Fix Duplicate Component Names ###
    # (?) Optional?
    if scope == SCOPE_MODEL
      fixed_components = self.fix_component_names
      if fixed_components > 0
        puts "> Fixed Duplicate Component Names: #{fixed_components}"
        stats['Duplicate Component Names Fixed'] = fixed_components
      end
    end
    
    ### Merge Materials ###
    if options[:merge_materials] 
      count = self.merge_similar_materials( model, options )
      stats['Materials Merged'] = count
    end
    
    ### Merge Coplanar Faces ###
    if options[:merge_faces] 
      stats['Edges Reduced'] = 0
      stats['Faces Reduced'] = model.number_faces if model.respond_to?(:number_faces)
      total_entities = self.count_scope_entity( scope, model )
      progress = TT::Progressbar.new( total_entities , 'Merging Faces' )
      count = self.each_entity_in_scope( scope, model ) { |e|
        progress.next
        begin
          self.merge_connected_faces(e, options)
        rescue SketchUpFaceMergeError => e
          errors << e
        end
      }
      stats['Edges Reduced'] += count
      stats['Faces Reduced'] -= model.number_faces if model.respond_to?(:number_faces)
    end
    
    ### Erase Duplicate Faces ###
    if options[:remove_duplicate_faces]
      stats['Faces Reduced'] ||= 0
      total_entities = self.count_scope_entity( scope, model )
      progress = TT::Progressbar.new( total_entities, 'Removing duplicate faces' )
      count = self.each_entities_in_scope( scope, model ) { |entities|
        self.erase_duplicate_faces(entities, progress)      
      }
      stats['Faces Reduced'] += count
      
      # Merge Coplanar Faces once more after removing duplicate faces.
      # Duplicate faces is not run first because it is so slow - pre-processing
      # and removing as many faces as possible is best.
      if options[:merge_faces] 
        stats['Edges Reduced'] = 0
        stats['Faces Reduced'] = model.number_faces if model.respond_to?(:number_faces)
        total_entities = self.count_scope_entity( scope, model )
        progress = TT::Progressbar.new( total_entities, 'Merging Faces' )
        count = self.each_entity_in_scope( scope, model ) { |e|
          progress.next
          begin
            self.merge_connected_faces(e, options)
          rescue SketchUpFaceMergeError => e
            errors << e
          end
        }
        stats['Edges Reduced'] += count
        stats['Faces Reduced'] -= model.number_faces if model.respond_to?(:number_faces)
      end
    end
    
    ### Repair Split Edges ###
    if options[:remove_lonely_edges] 
      stats['Edges Reduced'] ||= 0
      total_entities = self.count_scope_entity( scope, model )
      progress = TT::Progressbar.new( total_entities, 'Removing stray edges' )
      count = self.each_entities_in_scope( scope, model ) { |entities|
        self.erase_lonely_edges(entities, progress)
      }
      stats['Edges Reduced'] += count
    end
    
    ### Repair Split Edges ###
    if options[:repair_split_edges]
      stats['Edges Reduced'] ||= 0
      total_entities = self.count_scope_entity( scope, model )
      progress = TT::Progressbar.new( total_entities, 'Repairing split edges' )
      count = self.each_entities_in_scope( scope, model ) { |entities|
        TT::Edges.repair_splits( entities, progress )
      }
      stats['Edges Reduced'] += count
    end
    
    ### Post-process edges ###
    total_entities = self.count_scope_entity( scope, model )
    progress = TT::Progressbar.new( total_entities, 'Post Processing' )
    self.each_entity_in_scope( scope, model ) { |e|
      progress.next
      self.post_process(e, options)
    }
    
    ### Purge ###
    if options[:purge]
      # In case some components have become unused.
      size = model.definitions.length
      Sketchup.status_text = 'Purging Components...'
      model.definitions.purge_unused
      stats['Purged Components'] += size - model.definitions.length
      TT::SketchUp.refresh

      stats['Purged Layers'] = model.layers.length
      Sketchup.status_text = 'Purging Layers...'
      model.layers.purge_unused
      stats['Purged Layers'] -= model.layers.length
      TT::SketchUp.refresh
      
      stats['Purged Materials'] = model.materials.length
      Sketchup.status_text = 'Purging Materials...'
      model.materials.purge_unused
      stats['Purged Materials'] -= model.materials.length
      TT::SketchUp.refresh
      
      stats['Purged Styles'] = model.styles.count
      Sketchup.status_text = 'Purging Styles...'
      model.styles.purge_unused
      stats['Purged Styles'] -= model.styles.count
      TT::SketchUp.refresh
    end
    
    model.commit_operation
    TT::SketchUp.refresh
    
    ### Compile Statistics ###
    elapsed_time = TT::format_time( Time.now - stats['Total Elapsed Time'] )
    stats['Total Elapsed Time'] = elapsed_time
    # (?) Remove entries with 0 results?
    formatted_stats = stats.collect{|k,v|"> #{k}: #{v}"}.sort.join("\n")
    formatted_stats = "Cleanup Statistics:\n#{formatted_stats}"
    puts formatted_stats
    if options[:statistics]
      UI.messagebox( formatted_stats, MB_MULTILINE )
    end
    
    ### Validity Check ###
    if options[:validate]
      # This must be done outside any operations as it creates its own undo
      # entry in the undo-stack.
      # (i) Delay to avoid UI lockup - seem to be related to using the Inputbox class.
      #self.validity_check
      TT.defer { self.validity_check }
    end
    
    UI.refresh_inspectors
    
    Sketchup.status_text = 'Done!'
    
    # (!) Catch errors. Commit, inform user, offer to undo.
    self.report_errors( errors )
  end
  
  
  def self.count_scope_entity( scope, model )
    case scope
    when SCOPE_MODEL
      TT::Model.count_unique_entity( model, false )
    when SCOPE_LOCAL
      TT::Entities.count_unique_entity( model.active_entities )
    when SCOPE_SELECTED
      TT::Entities.count_unique_entity( model.selection )
    else
      raise ArgumentError, 'Invalid Scope'
    end
  end
  
  
  # (?) Unused?
  def self.count_scope_entities( scope, model )
    case scope
    when SCOPE_MODEL
      TT::Model.count_unique_entities( model, false )
    when SCOPE_LOCAL
      TT::Entities.count_unique_entities( model.active_entities )
    when SCOPE_SELECTED
      TT::Entities.count_unique_entities( model.selection )
    else
      raise ArgumentError, 'Invalid Scope'
    end
  end
  
  
  # Model entity iterator. Yields all unique entities in the scope.
  def self.each_entity_in_scope( scope, model, &block )
    case scope
    when SCOPE_MODEL
      TT::Model.each_entity( model, false, &block )
    when SCOPE_LOCAL
      TT::Entities.each_entity( model.active_entities, &block )
    when SCOPE_SELECTED
      TT::Entities.each_entity( model.selection, &block )
    else
      raise ArgumentError, 'Invalid Scope'
    end
  end
  
  
  def self.each_entities_in_scope( scope, model, &block )
    case scope
    when SCOPE_MODEL
      TT::Model.each_entities( model, false, &block )
    when SCOPE_LOCAL
      TT::Entities.each_entities( model.active_entities, &block )
    when SCOPE_SELECTED
      TT::Entities.each_entities( model.selection, &block )
    else
      raise ArgumentError, 'Invalid Scope'
    end
  end
  
  
  # Triggers SketchUp's model validity check.
  def self.validity_check
    if TT::System.is_windows?
      Sketchup.status_text = 'Checking validity. Please wait...'
      Sketchup.send_action(21124)
    end
  end
  
  
  # Post-process edges. Smooth and remove materials.
  def self.post_process(e, options)
    # Put on Layer 0
    if options[:geom_to_layer0]
      if e.is_a?( Sketchup::Edge ) || e.is_a?( Sketchup::Face )
        # Ensure the visibility inherited from the layer is transfered to the
        # entity.
        unless e.layer.visible?
          e.hidden = true
        end
        e.layer = nil
      end
    end
    return nil unless e.is_a?(Sketchup::Edge)
    # Remove Edge Material
    e.material = nil if options[:remove_edge_materials]
    # Smooth Edge
    if options[:smooth_angle] && options[:smooth_angle] > 0 && e.faces.length == 2
      angle = e.faces[0].normal.angle_between(e.faces[1].normal)
      if angle.radians.abs <= options[:smooth_angle]
        e.smooth = true
        e.soft = true
      end
    end
  end

  
  # Erase edges not connected to faces,
  # and edges that connects to the same face multiple times.
  def self.erase_lonely_edges(entities, progress)
    return 0 if entities.length == 0
    # Because entities can be an array, need to get a reference to the parent
    # Sketchup::Entities collection
    parent = entities.find { |e| e.valid? }.parent
    # Detect cutout component and protect edges on cut-plane.
    cutout = parent.is_a?( Sketchup::ComponentDefinition ) && parent.behavior.cuts_opening?
    # Find all edges not connected to any face and edges where all connected faces
    # are the same edge (some odd SketchUp glitch).
    edges = []
    for e in entities
      progress.next
      next unless e.valid? && e.is_a?(Sketchup::Edge)
      # Protect edges on the cut plane for cutouts
      next if cutout && e.vertices.all? { |v| v.position.on_plane?( GROUND_PLANE ) }
      # Pick out edges that doesn't connect to any faces or connect to the same
      # face multiple times. (Some times Sketchup edges has strange connections
      # like that.)
      if e.faces.size == 0 || 
         ( e.faces.size > 1 && e.faces.all?{ |f| f == e.faces[0] } )
        edges << e
      end
    end
    parent.entities.erase_entities(edges)
    return edges.size
  end
  
  
  # Custom error class for when SketchUp unexpectantly fails to merge two faces.
  class SketchUpFaceMergeError < Exception
  end
  
  
  # Merge coplanar faces by erasing the separating edge.
  # (?) Find all shared edges and erase them? Or was that tried earlier without
  # success?
  #
  # Returns true if the given entity was an edge separating two coplanar edges.
  # Return false otherwise.
  def self.merge_connected_faces(edge, options)   
    return false unless edge.valid? && edge.is_a?(Sketchup::Edge)
    # Coplanar edges only have two faces connected.
    return false unless edge.faces.size == 2
    f1, f2 = edge.faces
    # Ensure normals are correct.
    unless options[:merge_ignore_normals]
      # Normals are not ignored - ensure the faces is facing the same direction.
      # options[:merge_ignore_normals] == false
      unless f1.normal.samedirection?(f2.normal)
        return false
      end
    end
    # Don't try to merge faces sharing the same set of vertices.
    return false if self.face_duplicate?(f1, f2)
    # Check for troublesome faces which might lead to missing geometry if merged.
    return false unless self.edge_safe_to_merge?( edge )
    # Ensure materials match.
    unless options[:merge_ignore_materials]
      # Verify materials.
      if f1.material == f2.material && f1.back_material == f2.back_material
        # Verify UV mapping match.
        unless f1.material.nil? || f1.material.texture.nil? || options[:merge_ignore_uv]
          return false unless self.continuous_uv?(f1, f2, edge)
        end # unless options[:merge_ignore_uv]
      else
        return false
      end
    end # unless options[:merge_ignore_materials]
    # Ensure faces are co-planar.
    return false unless self.faces_coplanar?(f1, f2)
    # Edge passed all checks - safe to erase.
    edge.erase!
    # Verify that one of the connected faces are still valid.
    if f1.deleted? && f2.deleted?
      raise SketchUpFaceMergeError, 'Face merge resulted in lost geometry!'
    end
    true
  end
  
  
  # Checks the given edge for potential problems if the connected faces would
  # be merged.
  #
  # Test model:
  # * merge_bug_small_face_area.skp
  def self.edge_safe_to_merge?( edge )
    edge.faces.all? { |face| self.face_safe_to_merge?( face ) }
  end
  
  
  # Validates that the given face can be merged with other faces without causing
  # problems.
  def self.face_safe_to_merge?( face )
    stack = face.outer_loop.edges
    edge = stack.shift
    direction = edge.line[1]
    until stack.empty?
      edge = stack.shift
      return true unless edge.line[1].parallel?( direction )
    end
    # If the method exits here it means all edges in the face's outer loop is
    # considered parallel. This could lead to problems if the face is merged.
    return false
  end
  
  
  # Finds multiple faces for the same set of vertices and reduce them to one.
  # Erases faces overlapped by a larger face.
  # (!) Review this method.
  def self.erase_duplicate_faces(entities, progress)
    Sketchup.status_text = "Removing duplicate faces..."
    
    return 0 if entities.length == 0
    entities = entities.select { |e| e.valid? }
    parent = entities[0].parent.entities
    
    faces = entities.select { |e| e.is_a?(Sketchup::Face) }
    duplicates = [] # Confirmed duplicates.
    
    for face in faces.to_a # (?) needed .to_a ?
      progress.next
      next unless face.valid?
      next if duplicates.include?(face)
      connected = face.edges.map { |e| e.faces }
      connected.flatten!
      connected.uniq!
      connected &= entities
      connected.delete(face)
      for f in (connected - duplicates)
        next unless f.valid?
        duplicates << f if face_duplicate?(face, f, true)
      end # for
    end
    parent.erase_entities(duplicates) unless duplicates.empty?
    
    return duplicates.length
  end
  
  
  # Returns true if the two faces connected by the edge has continuous UV mapping.
  # UV's are normalized to 0.0..1.0 before comparison.
  def self.continuous_uv?( face1, face2, edge )
    tw = Sketchup.create_texture_writer
    uvh1 = face1.get_UVHelper( true, true, tw )
    uvh2 = face2.get_UVHelper( true, true, tw )
    p1 = edge.start.position
    p2 = edge.end.position
    self.uv_equal?( uvh1.get_front_UVQ(p1), uvh2.get_front_UVQ(p1) ) &&
    self.uv_equal?( uvh1.get_front_UVQ(p2), uvh2.get_front_UVQ(p2) ) &&
    self.uv_equal?( uvh1.get_back_UVQ(p1), uvh2.get_back_UVQ(p1) ) &&
    self.uv_equal?( uvh1.get_back_UVQ(p2), uvh2.get_back_UVQ(p2) )
  end
  
  
  # Normalize UV's to 0.0..1.0 and compare them.
  def self.uv_equal?( uvq1, uvq2 )
    uv1 = uvq1.to_a.map { |n| n % 1 }
    uv2 = uvq2.to_a.map { |n| n % 1 }
    uv1 == uv2
  end
  
  
  # Determines if two faces are coplanar.
  def self.faces_coplanar?(face1, face2)
    vertices = face1.vertices + face2.vertices
    plane = Geom.fit_plane_to_points( vertices )
    vertices.all? { |v| v.position.on_plane?(plane) }
  end
  
  
  # Determines if two faces occupy the same space.
  # (!) Review
  def self.face_duplicate?(face1, face2, overlapping = false)
    return false if face1 == face2
    v1 = face1.outer_loop.vertices
    v2 = face2.outer_loop.vertices
    return true if (v1 - v2).empty? && (v2 - v1).empty?
    #return true if overlapping && (v2 - v1).empty? # (!) error
    # A wee hack to determine if a face2 is fully overlapped by face1.
    if overlapping && (v2 - v1).empty?
      edges = (face2.outer_loop.edges - face1.outer_loop.edges)
      unless edges.empty?
        point = edges[0].start.position.offset(edges[0].line[1], 0.01)
        return true if face1.classify_point(point) <= 4
      end
    end
    return false
  end
  
  
  def self.merge_similar_materials( model, options )
    c = 0
    progress = TT::Progressbar.new( model.materials, 'Finding similar materials' )
    materials = model.materials
    stack = materials.to_a
    
    # key = old material
    # value = material to replace with
    matches = {}
    
    # Build list of replacements
    until stack.empty?
      progress.next
      proto_material = stack.shift
      ad1 = proto_material.attribute_dictionaries
      for material in stack.dup # (i) stack.to_a returns reference to self?
        next unless material.color.to_a == proto_material.color.to_a
        next unless material.alpha == proto_material.alpha
        next unless material.materialType == proto_material.materialType
        next unless material.texture.nil? == proto_material.texture.nil?
        if material.texture
          texture = material.texture
          proto_texture = proto_material.texture
          next unless texture.filename == proto_texture.filename
          next unless texture.width == proto_texture.width
          next unless texture.height == proto_texture.height
          next unless texture.image_width == proto_texture.image_width
          next unless texture.image_height == proto_texture.image_height
        end
        # Compare attribute dictionaries
        unless options[:merge_ignore_attributes]
          ad2 = material.attribute_dictionaries
          next unless TT::Attributes.dictionaries_equal?( ad1, ad2 )
        end
        
        matches[ material ] = proto_material
        stack.delete( material )
        c += 1
        
      end # for
    end # until stack.empty?
    
    # Replace materials
    count = TT::Model.count_unique_entity( model, false )
    progress = TT::Progressbar.new( count, 'Merging materials' )
    e = nil # Init variables for speed
    TT::Model.each_entity( model, false ) { |e|
      if e.respond_to?( :material )
        if replacement = matches[e.material]
          e.material = replacement
        end
      end
      if e.respond_to?( :back_material )
        if replacement = matches[e.back_material]
          e.back_material = replacement
        end
      end
      progress.next
    }
    
    # Remove materials
    self.remove_materials( model, matches.keys )
    
    c
  end
  
  
  def self.replace_materials( model, old_materials, new_material )
    count = TT::Model.count_unique_entity( model, false )
    progress = TT::Progressbar.new( count, "Merging material '#{new_material.display_name}'" )
    e = nil # Init variables for speed
    TT::Model.each_entity( model, false ) { |e|
      if e.respond_to?( :material )
        e.material = new_material if old_materials.include?( e.material )
      end
      if e.respond_to?( :back_material )
        e.back_material = new_material if old_materials.include?( e.back_material )
      end
      progress.next
    }
  end
  
  
  def self.remove_materials( model, materials )
    m = model.materials
    if m.respond_to?( :remove )
      for material in materials
        m.remove( material )
      end
    else
      # Workaround for SketchUp versions older than 8.0M1. Add all materials
      # except the one to be removed to temporary groups and purge the materials.
      temp_group = model.entities.add_group
      for material in model.materials
        next if materials.include?( material )
        g = temp_group.entities.add_group
        g.material = material
      end
      model.materials.purge_unused
      temp_group.erase!
      true
    end
  end
  
  
  def self.erase_hidden( model, scope )
    entity_count = self.count_scope_entity( scope, model )
    progress = TT::Progressbar.new( entity_count, 'Erasing hidden entities' )
    e = nil # Init variables for speed
    count = self.each_entity_in_scope( scope, model ) { |e|
      progress.next
      erased = false
      if e.valid?
        if e.is_a?( Sketchup::Edge )
          # Edges needs to be checked further
          if e.hidden? || e.soft? || !e.layer.visible?
            unless self.edge_protected?( e )
              e.erase!
              erased = true
            end
          end
        elsif e.hidden? || !e.layer.visible?
          # Everything else is safe to erase.
          e.erase!
          erased = true
        end # if edge?
      end
      erased
    }
  end
  
  
  def self.edge_protected?( edge )
    if edge.faces.any? { |edge| edge.visible? || edge.layer.visible? }
      return true
    end
    parent = edge.parent
    if parent.is_a?( Sketchup::ComponentDefinition ) && parent.behavior.cuts_opening?
      return true if edge.vertices.all? { |v| v.position.on_plane?( GROUND_PLANE ) }
    end
    false
  end
  
  
  # (!) Needs testing
  #
  # There has been cases where materials doesn't appear in the material list.
  # A material can be picked from an Image and used in the model where it won't
  # be listed in the material list UI, nor when model.material.each is iterated.
  #
  # With the introduction of model.materials.remove which doesn't automatically
  # remove the material from the model entities, there is a risk of ending up
  # with models where the material is not listed in the UI or even accessible
  # via the model.materials collection.
  #
  # These material can be removed or recreated.
  def self.fix_orphan_materials( model, options )
    materials = model.materials
    repair_materials = options[:fix_materials] == 'Repair'
    
    all_materials = (0...materials.count).map { |i| materials[i] }
    image_materials = all_materials.reject { |m| materials.include?(m) }
    
    # Build hash lookup for better performance.
    material_type = {}
    for material in all_materials
      if image_materials.include?( material )
        material_type[ material ] = :image
      else
        material_type[ material ] = :material
      end
    end
    
    setter = {
      :material => :material=,
      :back_material => :back_material=
    }
    
    # key: Orphan Material
    # value: New Repaired Material
    repairs = {}
    
    orphans = Set.new
    entity_count = TT::Model.count_unique_entity( model, false )
    progress = TT::Progressbar.new( entity_count, 'Looking for orphan materials' )
    e, key = nil # Init variables for speed
    TT::Model.each_entity( model, false ) { |e|
      progress.next
      
      [ :material, :back_material ].each { |key|
        next unless e.respond_to?( key )
        material = e.send( key )
        type = material_type[ material ]
        unless type == :material
          if repair_materials
            unless replacement = repairs[ material ]
              replacement = self.create_replacement_material( material, model )
              repairs[ material ] = replacement
            end
            e.send( setter[key], replacement )
          else
            e.send( setter[key], nil )
          end
        end
      }
    } # each entity
  end
  
  
  # Create new replacement material
  def self.create_replacement_material( material, model )
    new_material = model.materials.add( material.name )
    new_material.color = material.color
    new_material.alpha = material.alpha
    if material.texture
      if File.exist?( material.texture.filename )
        new_material.texture = material.texture.filename
      else
        filename = File.basename( material.texture.filename )
        temp_file = File.join( TT::System.temp_path, 'CleanUp', filename )
        temp_group = model.entities.add_group
        temp_group.material = material
        tw = Sketchup.create_texture_writer
        tw.load( temp_group )
        tw.write( temp_group, temp_file )
        new_material.texture = temp_file
        File.delete( temp_file )
        temp_group.erase!
      end
      new_material.texture.size = [ material.texture.width, material.texture.height ]
    end
    new_material
  end
  
  
  # Occationally some SketchUp models have multiple component definitions with
  # the same name. This is a bug which is not caught by SketchUp's own validation
  # process and can cause problems for plugins.
  # Checks the component names for duplicate names and ensures only unique names.
  def self.fix_component_names
    Sketchup.status_text = "Looking for multiple components of the same name..."
    
    model = Sketchup.active_model
    progress = TT::Progressbar.new( model.definitions, 'Looking for duplicate component names' )
    c = 0
    d = nil # Init variables for speed
    for definition in model.definitions
      progress.next
      copies = model.definitions.select { |d|
        d != definition && d.name == definition.name
      }
      next if copies.empty?
      puts "> Multiple definitions for '#{definition.name}' found!"
      for copy in copies
        puts "  > Renaming '#{copy.name}' to '#{model.definitions.unique_name(copy.name)}'..."
        copy.name = model.definitions.unique_name(copy.name)
        c += 1
      end
    end
    c
  end
  
  
  ### DEBUG ### ------------------------------------------------------------
  
  # TT::Plugins::CleanUp.reload
  def self.reload( reload_tt_lib=false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    TT::Lib.reload if reload_tt_lib
    load __FILE__
  ensure
    $VERBOSE = original_verbose
  end

end # module

#-----------------------------------------------------------------------------

file_loaded( __FILE__ )

#-----------------------------------------------------------------------------