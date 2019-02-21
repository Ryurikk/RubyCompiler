require 'fox16'
require 'fox16/colors'

include Fox

class Compiler < FXMainWindow

  def initialize(app)
    @activate = true
    @activate2 = false
    @inputs = false
    #--------------variables para analisis sintactico-------------------
    @reserved = ["integer","bool","float","do","until","write","read","if","end","while","else","then"]
    @operad = ["(",")","{","}","==","<=","!=",">=","<",">",",",":=",";","+","/","*","%","&","-","\"","#"]
    @tipo = ["integer", "float", "bool"]
    @linea = "num"
    @curtkn = "program"
    @anttkn = "program"
    @limini = 0
    @terminal
    @selected_items = []
    # -------------------------------------------
    icono = FXPNGIcon.new(app, File.open("iconos/ruby.png","rb").read)
    super(app,"ARCEVS COMPILER",:icon=>icono,:width => 900,:height => 700)
    self.connect(SEL_CLOSE, method(:on_close))
    self.connect(SEL_SESSION_CLOSED, method(:on_close))
    menu_bar #Colocamos nuestra barra de Menu
    botones #Colocamos los botones de las funcionalidades del menu
    @status = FXText.new(self,nil,0,LAYOUT_FILL_X|TEXT_READONLY|LAYOUT_SIDE_BOTTOM,:height => 10)
    malla = FXSplitter.new(self,LAYOUT_SIDE_TOP|LAYOUT_FILL_X|LAYOUT_FILL_Y|
        SPLITTER_VERTICAL|SPLITTER_REVERSED)
    data = FXSplitter.new(malla,LAYOUT_SIDE_TOP|LAYOUT_FILL_X|LAYOUT_FILL_Y|SPLITTER_REVERSED)
    text_area(data) #Ponemos un area de Texto
    compile_pane(data) #Ponemos un pane al lado del texto
    compile_pane2(malla) #Colocamos un pane de resultados
    @archivo = ""
    @cambios = false
  end

  def create
    super
    show(PLACEMENT_SCREEN)
  end

  def on_close(sender, sel, event)
    @activate = false
    @hilo.kill
    return 0;
  end

  def iconos(file)
    begin
      icon = nil
      File.open(file, "rb") do |doc|
        icon = FXPNGIcon.new(getApp(), doc.read)
      end
      icon
    rescue
      raise RuntimeError, "No se pudo abrir: #{file}"
    end
  end

  def botones
    frame = FXHorizontalFrame.new(self,LAYOUT_FILL_X|LAYOUT_RESERVED_1)
    newr = FXButton.new(frame,"&",:icon => iconos("iconos/nuevo.png"),:opts => BUTTON_TOOLBAR)
    newr.connect(SEL_COMMAND) do
      nuevo
    end
    cerr = FXButton.new(frame,"&",:icon => iconos("iconos/cerrar.png"),:opts => BUTTON_TOOLBAR)
    cerr.connect(SEL_COMMAND) do
      cerrar
    end
    cerr
    open = FXButton.new(frame,"&",:icon => iconos("iconos/abrir.png"),:opts => BUTTON_TOOLBAR)
    open.connect(SEL_COMMAND) do
      abrir
    end
    save = FXButton.new(frame,"&",:icon => iconos("iconos/guardar.png"),:opts => BUTTON_TOOLBAR)
    save.connect(SEL_COMMAND) do
      guardar
    end
    save2 = FXButton.new(frame,"&",:icon => iconos("iconos/guardarcomo.png"),:opts => BUTTON_TOOLBAR)
    save2.connect(SEL_COMMAND) do
      guardar_como
    end
    compi = FXButton.new(frame,"&",:icon => iconos("iconos/compilar.png"),:opts => BUTTON_TOOLBAR)
    compi.connect(SEL_COMMAND) do
      compilar
    end
    ejecu = FXButton.new(frame,"&",:icon => iconos("iconos/ejecutar.png"),:opts => BUTTON_TOOLBAR)
    ejecu.connect(SEL_COMMAND) do
      ejecutar
    end
    coej = FXButton.new(frame,"&",:icon => iconos("iconos/coej.png"),:opts => BUTTON_TOOLBAR)
    coej.connect(SEL_COMMAND) do
      comeje
    end
  end

  def menu_bar
    menubar = FXMenuBar.new(self,LAYOUT_SIDE_TOP|LAYOUT_FILL_X)

    file_menu = FXMenuPane.new(self)
    edit_menu = FXMenuPane.new(self)
    FXMenuTitle.new(menubar,"Archivo",:popupMenu => file_menu)
    FXMenuTitle.new(menubar,"Ejecutar",:popupMenu => edit_menu)

    nuevo_cmd = FXMenuCommand.new(file_menu,"Nuevo")
    abrir_cmd = FXMenuCommand.new(file_menu,"Abrir")
    saves_cmd = FXMenuCommand.new(file_menu,"Guardar")
    savesh_cmd = FXMenuCommand.new(file_menu,"Guardar Como")
    close_cmd = FXMenuCommand.new(file_menu,"Cerrar")
    salir_cmd = FXMenuCommand.new(file_menu,"Salir")

    comp_cmd = FXMenuCommand.new(edit_menu,"Compilar")
    ejec_cmd = FXMenuCommand.new(edit_menu,"Ejecutar")
    coej_cmd = FXMenuCommand.new(edit_menu,"Compilar y Ejecutar")

    nuevo_cmd.connect(SEL_COMMAND) do
      nuevo
    end
    abrir_cmd.connect(SEL_COMMAND) do
      abrir
    end
    saves_cmd.connect(SEL_COMMAND) do
      guardar
    end
    savesh_cmd.connect(SEL_COMMAND) do
      guardar_como
    end
    close_cmd.connect(SEL_COMMAND) do
      cerrar
    end
    salir_cmd.connect(SEL_COMMAND) do
      @hilo.kill
      self.close
    end

    comp_cmd.connect(SEL_COMMAND) do
      compilar
    end
    ejec_cmd.connect(SEL_COMMAND) do
      ejecutar
    end
    coej_cmd.connect(SEL_COMMAND) do
      comeje
    end
  end

  def text_area(malla)
    textframe = FXHorizontalFrame.new(malla,LAYOUT_SIDE_TOP|LAYOUT_FILL_X|FRAME_THICK)
    @counter = FXText.new(textframe,nil,0,LAYOUT_FILL_Y|TEXT_READONLY|VSCROLLER_NEVER,:width => 50)
    @counter.setBackColor(Fox.FXRGB(169, 169, 169))
    @counter.connect(SEL_CLICKED) do
      @counter.killSelection(true)
    end
    @texto = FXText.new(textframe,nil,0,TEXT_WORDWRAP|LAYOUT_FILL_X|LAYOUT_FILL_Y)
    @texto.setNumberColor(Fox.FXRGB(205,  92,  92))
    @texto.connect(SEL_CHANGED) do
      @status.text = "Fil: "<<(@texto.getCursorRow + 1).to_s<<" Col: "<<(@texto.getCursorColumn + 1).to_s
      countlin(@texto.numRows)
      @counter.setPosition(0,@texto.getYPosition.to_s.to_i)
      @cambios = true
      painter
    end
    @hilo = Thread.new{
      while @activate do
        sleep 0.001
        @counter.setPosition(0,@texto.getYPosition.to_s.to_i)
      end
    }
    @executer = Thread.new{
      while true
        if !@activate2
          sleep 3
        else
          tinyMachineRun
          @activate2 = false
        end
      end
    }
    #Inicializamos los estilos de texto:
    hs0 = FXHiliteStyle.from_text(@texto)
      hs0.normalForeColor = FXColor::Black
      hs0.style = FXText::STYLE_BOLD
    hs1 = FXHiliteStyle.from_text(@texto)
      hs1.normalForeColor = FXColor::Red
    hs2 = FXHiliteStyle.from_text(@texto)
      hs2.normalForeColor = FXColor::Blue
    hs3 = FXHiliteStyle.from_text(@texto)
      hs3.normalForeColor = FXColor::DarkGreen
    hs4 = FXHiliteStyle.from_text(@texto)
      hs4.normalForeColor = FXColor::DarkGoldenrod
    hs5 = FXHiliteStyle.from_text(@texto)
      hs5.normalForeColor = FXColor::DarkCyan
      hs5.style = FXText::STYLE_BOLD
    @texto.styled = true
    @texto.hiliteStyles = [hs0, hs1, hs2, hs3, hs4, hs5]
  end

  def countlin(num)
    @counter.text = ""
    val = num
    while num > 0 do
      @counter.appendText((val-num+1).to_s<<"\n")
      num = num-1
    end
  end

  def painter
    reservadas = %w[main if then else end do while repeat until float read write cout real integer bool]
    letras = %w[a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z _]
    numeros = %w[0 1 2 3 4 5 6 7 8 9]
    token = ""
    @initok = []
    col = 0
    lcn = @texto.countLines(0,@texto.length)
    r = 0
    while r <= lcn
      i = 0
      linea = @texto.extractText(col,@texto.lineEnd(col)-col)
      while i < linea.to_s.length
        token = ""
        if letras.find_index(linea[i])
          token += linea[i]
          i += 1
          while letras.find_index(linea[i]) || numeros.find_index(linea[i])
            token += linea[i]
            i += 1
          end
          if reservadas.find_index(token)
            colorear(token,i+col,3)
          else
            colorear(token,i+col,1)
          end
        elsif (numeros.find_index(linea[i]))
          entero = true
          nump = i
          token += linea[i]
          punto = 0
          i += 1
          while numeros.find_index(linea[i]) || linea[i]=='.'
            if(linea[i]=='.')
              if(punto==0)
                entero = false
                token += linea[i]
                i += 1
                if(numeros.find_index(linea[i]))
                  token += linea[i]
                  i += 1
                  while numeros.find_index(linea[i])
                    token += linea[i]
                    i += 1
                  end
                end
                punto += 1
              end
              break
            elsif (numeros.find_index(linea[i]))
              token += linea[i]
              i += 1
              while numeros.find_index(linea[i])
                token += linea[i]
                i += 1
              end
            end
          end
          colorear(token,i+col,2)
        elsif (linea[i] == '/')
          token += linea[i]
          i += 1
          gur = col+i
          if (linea[i] == '/')
            #------------------------------comentario----------------------------------
            col = @texto.nextLine(col)
            linea = @texto.extractText(col,@texto.lineEnd(col)-col)
            r += 1
            i = 0
            comentarios(gur,col+i)
          elsif (linea[i] == '*')
            #-----------------------------comentario multilinea-----------------------------
            i += 1
            finer = false
            comMul = true
            while comMul
              if linea[i] == "\n" || linea[i] == nil
                col = @texto.nextLine(col)
                linea = @texto.extractText(col,@texto.lineEnd(col)-col)
                r += 1
                i = 0
                if lcn - r < 0 then
                  finer = true
                  comMul = false
                end
              elsif linea[i] == '*' && linea[i+1] == '/'
                #-------------------- final de comentario multilinea--------------------
                i += 2
                comMul = false
              else
                i += 1
              end
            end
            if finer
              comentarios(gur,@texto.length)
            else
              comentarios(gur,i+col)
            end
          else
            colorear(token,i+col,6)
          end
        elsif (linea[i]=="\"")
          ini = col+i
          i += 1
          lin = true
          find = false
          while lin
            if linea[i] == "\n" || linea[i] == nil
              col = @texto.nextLine(col)
              linea = @texto.extractText(col,@texto.lineEnd(col)-col)
              r += 1
              i = 0
              if lcn - r < 0 then
                lin = false
              end
            elsif linea[i] == "\""
              i += 1
              lin = false
              find = true
            else
              i += 1
            end
          end
          if find
            cadenas(ini, col+i)
          else
            cadenas(ini,@texto.length)
          end
        elsif (linea[i]=='+')
          token += linea[i]
          i += 1
          if (linea[i]=='+')
            token += linea[i]
            i += 1
          end
          colorear(token,i+col,6)
        elsif (linea[i]=='-')
          token += linea[i]
          i += 1
          if (linea[i]=='-')
            token += linea[i]
            i += 1
            colorear(token,i+col,6)
          else
            colorear(token,i+col,6)
          end
        elsif (linea[i]=='<')
          token += linea[i]
          i += 1
          if (linea[i]=='=')
            token += linea[i]
            i += 1
          end
          colorear(token,i+col,6)
        elsif (linea[i]=='>')
          token += linea[i]
          i += 1
          if (linea[i]=='=')
            token += linea[i]
            i += 1
          end
          colorear(token,i+col,6)
        elsif (linea[i]=='=')
          token += linea[i]
          i += 1
          if (linea[i]=='=') then
            token += linea[i]
            i += 1
            colorear(token,i+col,6)
          else
            colorear(token,i+col,0)
          end
        elsif (linea[i]=='!')
          token += linea[i]
          i += 1
          if (linea[i]=='=') then
            token += linea[i]
            i += 1
            colorear(token,i+col,6)
          end
        elsif (linea[i] == ':')
          token += linea[i]
          i += 1
          if (linea[i] == '=') then
            token += linea[i]
            i += 1
            colorear(token,i+col,6)
          end
        elsif (linea[i] == ';')
          token += linea[i]
          i += 1
          colorear(token,i+col,0)
        elsif (linea[i] == ',')
          token += linea[i]
          i += 1
          colorear(token,i+col,0)
        elsif (linea[i] == '%')
          token += linea[i]
          i += 1
          colorear(token,i+col,6)
        elsif (linea[i] == '(')
          token += linea[i]
          i += 1
          colorear(token,i+col,0)
        elsif (linea[i] == ')')
          token += linea[i]
          i += 1
          colorear(token,i+col,0)
        elsif (linea[i] == '{')
          token += linea[i]
          i += 1
          colorear(token,i+col,0)
        elsif (linea[i] == '}')
          token += linea[i]
          i += 1
          colorear(token,i+col,0)
        elsif (linea[i] == '*')
          token += linea[i]
          i += 1
          colorear(token,i+col,6)
        elsif (linea[i] == " ")
          i += 1
        elsif (linea[i] == "\n")
          i += 1
        elsif (linea[i] == "\t")
          i += 1
        else
          token += linea[i]
          i += 1
        end
      end
      col = @texto.nextLine(col)
      r += 1
    end
  end

  def colorear(token,pos,sty)
    f,l = @texto.findText(token.to_s,start = pos, flags = SEARCH_BACKWARD|SEARCH_EXACT)
    d = 0
    lim = @texto.lineStart(pos)
    begin
      while l[0] > pos && (pos-d) >= lim do
        d += 1
        f,l = @texto.findText(token.to_s,start = pos-d, flags = SEARCH_BACKWARD|SEARCH_EXACT)
      end
      if f != nil && f[0] >= lim then
        @texto.changeStyle(f[0],l[0]-f[0],sty)
      end
    rescue
      f,l = @texto.findText(token.to_s,start = @texto.lineEnd(pos), flags = SEARCH_BACKWARD|SEARCH_EXACT)
      if f != nil && l[0] >= pos then
        @texto.changeStyle(f[0],l[0]-f[0],sty)
      end
    end
  end

  def comentarios(ini, pos)
    @texto.changeStyle(ini-1,pos-ini+1,4)
  end

  def cadenas(ini, pos)
    @texto.changeStyle(ini,pos-ini,5)
  end

  def compile_pane(malla)
    paneframe = FXHorizontalFrame.new(malla,LAYOUT_SIDE_TOP|LAYOUT_FILL_X|FRAME_SUNKEN)
    @compl = FXTabBook.new(paneframe,nil,0,TABBOOK_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_Y)
    @lex = FXTabItem.new(@compl,"Léxico", ic = nil, opts = TAB_BOTTOM_NORMAL)
    lexframe = FXHorizontalFrame.new(@compl, FRAME_THICK)
    @lexCon = FXList.new(lexframe, :opts => LIST_EXTENDEDSELECT|LAYOUT_FILL_X|LAYOUT_FILL_Y|TEXT_READONLY) #Lista del elemento Compile
    @sin = FXTabItem.new(@compl,"Sintáctico", ic = nil, opts = TAB_BOTTOM_NORMAL)
    sinframe = FXHorizontalFrame.new(@compl, FRAME_THICK)
    #@sinCon = FXList.new(sinframe, :opts => LIST_EXTENDEDSELECT|LAYOUT_FILL_X|LAYOUT_FILL_Y|TEXT_READONLY) #Lista del elemento Compile
    @sinCon = FXTreeList.new(sinframe, :opts => TREELIST_NORMAL|TREELIST_SHOWS_LINES|TREELIST_SHOWS_BOXES|TREELIST_ROOT_BOXES|LAYOUT_FILL)
    @sem = FXTabItem.new(@compl,"Semántico", ic = nil, opts = TAB_BOTTOM_NORMAL)
    semframe = FXHorizontalFrame.new(@compl, FRAME_THICK)
    #Lista del elemento Compile
    @semCon = FXTreeList.new(semframe, :opts => TREELIST_NORMAL|TREELIST_SHOWS_LINES|TREELIST_SHOWS_BOXES|TREELIST_ROOT_BOXES|LAYOUT_FILL)
    @int =FXTabItem.new(@compl,"Intermedio", ic = nil, opts = TAB_BOTTOM_NORMAL)
    intframe = FXHorizontalFrame.new(@compl, FRAME_THICK)
    @intCon = FXList.new(intframe, :opts => LIST_EXTENDEDSELECT|LAYOUT_FILL_X|LAYOUT_FILL_Y|TEXT_READONLY) #Lista del elemento Compile
    #----------------Funcionalidad del Arbol Sintactico---------------------------
    @sinCon.connect(SEL_SELECTED) do |sender, sel, item|
      @selected_items << item unless @selected_items.include? item
    end
    @sinCon.connect(SEL_DESELECTED) do |sender, sel, item|
      @selected_items.delete(item)
    end

    @sinCon.connect(SEL_COMMAND) do |sender, sel, current|
      @selected_items = []
      @sinCon.each { |child| add_selected_items(child, @selected_items) }
    end
    #-----------------------------------------------------------------------------
  end

  def add_selected_items(item, selected_items)
    selected_items << item if item.selected?
    item.each { |child| add_selected_items(child, selected_items) }
  end

  def compile_pane2(malla)
    paneframe = FXHorizontalFrame.new(malla,LAYOUT_SIDE_TOP|LAYOUT_FILL_X|FRAME_SUNKEN)
    @result = FXTabBook.new(paneframe,nil,0,TABBOOK_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_Y)
    @res = FXTabItem.new(@result,"Resultado", ic = nil, opts = TAB_BOTTOM_NORMAL)
    resframe = FXHorizontalFrame.new(@result, FRAME_THICK)
    @resCon = FXText.new(resframe, :opts => LIST_EXTENDEDSELECT|LAYOUT_FILL_X|LAYOUT_FILL_Y) #Texto del elemento Resultado
    @err = FXTabItem.new(@result,"Errores", ic = nil, opts = TAB_BOTTOM_NORMAL)
    errframe = FXHorizontalFrame.new(@result, FRAME_THICK)
    @errCon = FXList.new(errframe, :opts => LIST_EXTENDEDSELECT|LAYOUT_FILL_X|LAYOUT_FILL_Y|TEXT_READONLY) #Lista del elemento Resultado
    @sim = FXTabItem.new(@result,"Símbolos", ic = nil, opts = TAB_BOTTOM_NORMAL)
    simframe = FXHorizontalFrame.new(@result, FRAME_THICK)
    @simCon = FXList.new(simframe, :opts => LIST_EXTENDEDSELECT|LAYOUT_FILL_X|LAYOUT_FILL_Y|TEXT_READONLY) #Lista del elemento Resultado
    @resCon.connect(SEL_KEYPRESS) do |sd,sl,dt|
      if dt.code == KEY_Return
        @inputs = false
      end
    end
  end

  def add_text(path)
    @texto.text = ""
    File.open(path,'rb').each_line do |line|
      line.gsub!(/\r\n?/, "\n")
      #line.gsub!(/[íìï]/, "i")
      #line.gsub!(/áàä/, "a")
      #line.gsub!(/éèë/, "e")
      #line.gsub!(/óòö/, "o")
      #line.gsub!(/úùü/, "u")
      #line.gsub!(/ÍÌÏ/, "I")
      #line.gsub!(/ÁÀÄ/, "A")
      #line.gsub!(/ÉÈË/, "E")
      #line.gsub!(/ÓÒÖ/, "O")
      #line.gsub!(/ÚÙÜ/, "U")
      @texto.appendText(line.to_s)
    end
    painter
    countlin(@texto.numRows)
  end

  def cerrar
    perdidas
    @archivo = ""
    @texto.text = ""
    @counter.text = ""
    @lexCon.clearItems
    @sinCon.clearItems
    @semCon.clearItems
    @intCon.clearItems
    @resCon.text = ""
    @errCon.clearItems
    @simCon.clearItems
    @cambios = false
  end

  def nuevo
    perdidas
    @archivo = ""
    @texto.text = ""
    @counter.text = ""
    @lexCon.clearItems
    @sinCon.clearItems
    @semCon.clearItems
    @intCon.clearItems
    @resCon.text = ""
    @errCon.clearItems
    @simCon.clearItems
    @cambios = false
  end

  def abrir
    perdidas
    ventana = FXFileDialog.new(self, "Abrir Codigo")
    if ventana.execute != 0
      @archivo = ventana.filename
      add_text(ventana.filename)
      @cambios = false
    end
  end

  def guardar
    if @archivo == ""
      ventana = FXFileDialog.new(self,"Guardar Codigo")
      if ventana.execute != 0
        if ventana.getFilename != ""
          File.write(ventana.getFilename,@texto.text)
        else
          File.write(File.join(ventana.getDirectory,"main.txt"),@texto.text)
        end
      end
    else
      File.write(@archivo,@texto.text)
    end
    @cambios = false
  end

  def guardar_como
    ventana = FXFileDialog.new(self,"Guardar Codigo")
      if ventana.execute != 0
        if ventana.getFilename != ""
          if File.exist?(ventana.getFilename)
            q = FXMessageBox.question(getApp(), MBOX_YES_NO, "Sobreescritura", "¿Seguro que quieres sobreescribir este archivo?")
            if q == MBOX_CLICKED_YES
              File.write(ventana.getFilename,@texto.text)
            end
          else
            File.write(ventana.getFilename,@texto.text)
          end
        else
          File.write(File.join(ventana.getDirectory,"main.txt"),@texto.text)
        end
      end
    @cambios = false
  end

  def perdidas
    if @cambios
      q = FXMessageBox.question(getApp(), MBOX_YES_NO, "Hay cambios", "Quieres guardar antes de proceder?")
      if q == MBOX_CLICKED_YES
        if @archivo == ""
          guardar_como
        else
          guardar
        end
      end
    end
  end

  def compilar
    if @archivo != "" then
      analizadorLexico
    end
    @sinCon.clearItems
    @semCon.clearItems
    @intCon.clearItems
    @simCon.clearItems
  end

  def ejecutar
    @sinCon.clearItems
    @semCon.clearItems
    @intCon.clearItems
    @resCon.text = ""
    @errCon.clearItems
    @simCon.clearItems
    if @archivo != "" then
      @size = File.readlines("metadata/tokens.txt").size
      @id = 0
      programa
      @symbotable = Hash.new(0)
      copyTree(@sinCon.getFirstItem,nil)
      expandir(@sinCon.getFirstItem,@semCon.getFirstItem)
      semanticAnalize(@semCon.getFirstItem)
      changer(@semCon.getFirstItem)
      @labeler = 0
      pCode(@semCon.getFirstItem)
      @intCon.appendItem("STP")
      #imprimimos los datos
      @symbotable.each do |key, value|
        @simCon.appendItem("["+value.getName+","+value.getType+","+value.getValue.to_s+","+value.getSequ.to_s+"]")
      end
    end
  end

  def comeje
    if @sinCon.getFirstItem != nil
      @tmpOff = 0
      @highPointer = 0
      @pointer = 0
      @objetivo = File.open("metadata/objetive.txt", 'w')
      emitRM("LD",6,0,0)
      emitRM("ST",0,0,0)
      objCode(@sinCon.getFirstItem)
      @objetivo.puts(@pointer.to_s+": HALT 0,0,0")
      @objetivo.close
      initialization(true)
      if !readInstructions() then
        return 0
      end
      @activate2 = true
    end
  end
end

class DataTyper
  def initialize(tipo,valor)
    @valuen = valor
    @typen = tipo
  end

  def getType
    @typen
  end

  def getValue
    @valuen
  end
end

class SymboTab
  def initialize(nombre,tipo,valor,sequ)
    @nombres = nombre
    @values = valor
    @types = tipo
    @seque = sequ
  end

  def getType
    @types
  end

  def getValue
    @values
  end

  def getName
    @nombres
  end

  def getSequ
    @seque
  end
end

#-------------------------------------Analizador Sintáctico-------------------------------------
@Err = "E"
def programa
  peektkn
  cero = @sinCon.appendItem(nil,"main")
  #Añadido de linea
    @sinCon.setItemData(cero,@linea)
  if @curtkn == "main" then
    peektkn
    if @curtkn == "{" then
      peektkn
      if declSeq(cero) then
        if stmtSeq(cero) then
          if @curtkn == "}" then
            @errCon.appendItem("Analisis Finalizado!")
          else
            if @Err == "E" then
              @Err = "Error. Se esperaba un } al final del código."
            end
            prterr
          end
        else
          if @curtkn == "}" then
            @errCon.appendItem("Analisis Finalizado!")
          else
            if @Err == "E" then
              @Err = "Error. Se esperaba un } al final del código."
            end
            prterr
          end
        end
      end
    else
      if @Err == "E" then
        @Err = "No se esperaba #{@curtkn}, se esperaba un { en el programa."
      end
      prterr
    end
  else
    @sinCon.setItemText(cero, "Error")
    if @Err == "E" then
      @Err = "No se esperaba #{@curtkn}, se esperaba el identificador \"main\" en el programa."
    end
    prterr
    if @curtkn == "{" then
      peektkn
      if declSeq(cero) then
        if stmtSeq(cero) then
          if @curtkn == "}" then
            @errCon.appendItem("Analisis Finalizado!")
          else
            if @Err == "E" then
              @Err = "Error. Se esperaba un } al final del código."
            end
            prterr
          end
        else
          if @curtkn == "}" then
            @errCon.appendItem("Analisis Finalizado!")
          else
            if @Err == "E" then
              @Err = "Error. Se esperaba un } al final del código."
            end
            prterr
          end
        end
      end
    else
      if @Err == "E" then
        @Err = "No se esperaba #{@curtkn}, se esperaba un { en el programa."
      end
      prterr
      if declSeq(cero) then
        if stmtSeq(cero) then
          if @curtkn == "}" then
            @errCon.appendItem("Analisis Finalizado!")
          else
            if @Err == "E" then
              @Err = "Error. Se esperaba un } al final del código."
            end
            prterr
          end
        else
          if @curtkn == "}" then
            @errCon.appendItem("Analisis Finalizado!")
          else
            if @Err == "E" then
              @Err = "Error. Se esperaba un } al final del código."
            end
            prterr
          end
        end
      end
    end
  end
end

#Funcion de Impresion de Errores
def prterr
  @errCon.appendItem(@Err.to_s+" Linea: "+@linea.to_s)
  @Err = "E"
end

#Expresion de secuencia de declaraciones
def declSeq(tr)
  if declare(tr) then
    if @curtkn == ";" then
      peektkn
      declSeq(tr)
    else
      if @Err == "E" then
        @Err = "No se esperaba #{@curtkn}, se esperaba ; para finalizar la declaración."
      end
      prterr
      declSeq(tr)
    end
  else
    return true
  end
end

#Expresion de declaracion
def declare(tr1)
  if typer then
    tr = @sinCon.appendItem(tr1, "declaracion")
    #Añadido de linea
      @sinCon.setItemData(tr,@linea)
    tr2 = @sinCon.appendItem(tr,@anttkn)
    #Añadido de linea
      @sinCon.setItemData(tr2,@linea)
    if variables(tr) then
      return true
    else
      return false
    end
  else
    return false
  end
end

#Expresion de variables
def variables(tr1)
  if ident then
    t2 = @sinCon.appendItem(tr1,@anttkn)
    #Añadido de linea
      @sinCon.setItemData(t2,@linea)
    if @curtkn == "," then
      peektkn
      variables(tr1)
    else
      return true
    end
  else
    if @Err == "E" then
      @Err = "No se esperaba #{@curtkn}, se esperaba un identificador."
    end
    t2 = @sinCon.appendItem(tr1,"Error")
    #Añadido de linea
      @sinCon.setItemData(t2,@linea)
    prterr
    if @curtkn == ";" then
      return true
    else
      peektkn
      variables(tr1)
    end
  end
end

#Expresion de secuencia de sentencias.
def stmtSeq(tr)
  if stmt(tr) then
    if @id < @size then
      stmtSeq(tr)
    else
      return true
    end
  else
    return false
  end
end

#Expresion de sentencias.
def stmt(tr)
  if assing(tr)
    if @curtkn == ";" then
      if @id < @size then
        peektkn
      end
      return true
    else
      if @Err == "E" then
        @Err = "No se encuentra ; al final de la sentencia de asignacion."
      end
      prterr
      return true
    end
  elsif lectura(tr)
    if @curtkn == ";" then
      if @id < @size then
        peektkn
      end
      return true
    else
      if @Err == "E" then
        @Err = "No se encuentra ; al final de la sentencia read."
      end
      prterr
      return true
    end
  elsif escritura(tr)
    if @curtkn == ";" then
      if @id < @size then
        peektkn
      end
      return true
    else
      if @Err == "E" then
        @Err = "No se encuentra ; al final de la sentencia write."
      end
      prterr
      return true
    end
  elsif ifst(tr)
    return true
  elsif whiler(tr)
    return true
  elsif repetir(tr)
    if @curtkn == ";" then
      if @id < @size then
        peektkn
      end
      return true
    else
      if @Err == "E" then
        @Err = "No se encuentra ; al final de la sentencia do-until."
      end
      prterr
      return true
    end
  else
    if @curtkn == ";"
      if @Err == "E" then
        @Err = "Hay un punto y coma pero no hay expresión que evaluar."
      end
      prterr
      peektkn
      return true
    else
      if !@reserved.include?(@curtkn) && @curtkn != "}"
        peektkn
        return true
      elsif @tipo.include?(@curtkn)
        declSeq(tr)
      else
        return false
      end
    end
  end
end

#Expresion de tipos.
def typer
  if @tipo.include?(@curtkn) then
    @anttkn = @curtkn
    peektkn
    return true
  else
    return false
  end
end

#Expresion de numeros.
def num
  true if Float(@curtkn) rescue false
end

#Expresion de identificadores.
def ident
  if !@reserved.include?(@curtkn) && !@operad.include?(@curtkn) && !num then
    @anttkn = @curtkn
    peektkn
    return true
  else
    return false
  end
end

def ident_decl
  if !@reserved.include?(@curtkn) && !@operad.include?(@curtkn) && !num then
    @anttkn = @curtkn
    rwntkn
    return true
  else
    return false
  end
end

#Expresion de repeticion.
def repetir(tr1)
  if @curtkn == "do" then
    tr = @sinCon.appendItem(tr1,"do")
    #Añadido de linea
      @sinCon.setItemData(tr,@linea)
    peektkn
    if bloque("do-until",tr) then
      if @curtkn == "until" then
        tr2 = @sinCon.appendItem(tr,"until")
        #Añadido de linea
          @sinCon.setItemData(tr2,@linea)
        peektkn
        if @curtkn == "(" then
          peektkn
          if expr_search(tr2) then  #cambio de tr a tr2
            if @curtkn == ")" then
              peektkn
              return true
            else
              if @Err == "E" then
                @Err = "No se esperaba #{@curtkn}, necesitamos un parentesis de cierre en do-while."
              end
              prterr
              return true
            end
          end
        else
          if @Err == "E" then
            @Err = "No se esperaba #{@curtkn}, necesitamos un parentesis de apertura en do-while."
          end
          prterr
          if expr_search(tr2) then  #cambio de tr a tr2
            if @curtkn == ")" then
              peektkn
              return true
            else
              if @Err == "E" then
                @Err = "No se esperaba #{@curtkn}, necesitamos un parentesis de cierre en do-while."
              end
              prterr
              return true
            end
          end
        end
      else
        if @Err == "E" then
          @Err = "No se esperaba #{@curtkn}, se esperaba until en la sentencia."
        end
        prterr
        if @curtkn == "(" then
          peektkn
          if expr_search(tr2) then  #cambio de tr a tr2
            if @curtkn == ")" then
              peektkn
              return true
            else
              if @Err == "E" then
                @Err = "No se esperaba #{@curtkn}, necesitamos un parentesis de cierre en do-while."
              end
              prterr
              return true
            end
          end
        else
          if @Err == "E" then
            @Err = "No se esperaba #{@curtkn}, necesitamos un parentesis de apertura en do-while."
          end
          prterr
          if expr_search(tr2) then  #cambio de tr a tr2
            if @curtkn == ")" then
              peektkn
              return true
            else
              if @Err == "E" then
                @Err = "No se esperaba #{@curtkn}, necesitamos un parentesis de cierre en do-while."
              end
              prterr
              return true
            end
          end
        end
      end
    else
      if @curtkn == "until" then
        tr2 = @sinCon.appendItem(tr,"until")
        #Añadido de linea
          @sinCon.setItemData(tr2,@linea)
        peektkn
        if @curtkn == "(" then
          peektkn
          if expr_search(tr) then
            if @curtkn == ")" then
              peektkn
              return true
            else
              if @Err == "E" then
                @Err = "No se esperaba #{@curtkn}, necesitamos un parentesis de cierre en do-while."
              end
              prterr
              return true
            end
          end
        else
          if @Err == "E" then
            @Err = "No se esperaba #{@curtkn}, necesitamos un parentesis de apertura en do-while."
          end
          prterr
          if expr_search(tr2) then  #cambio de tr a tr2
            if @curtkn == ")" then
              peektkn
              return true
            else
              if @Err == "E" then
                @Err = "No se esperaba #{@curtkn}, necesitamos un parentesis de cierre en do-while."
              end
              prterr
              return true
            end
          end
        end
      else
        if @Err == "E" then
          @Err = "No se esperaba #{@curtkn}, se esperaba until en la sentencia."
        end
        prterr
        if @curtkn == "(" then
          peektkn
          if expr_search(tr2) then  #cambio de tr a tr2
            if @curtkn == ")" then
              peektkn
              return true
            else
              if @Err == "E" then
                @Err = "No se esperaba #{@curtkn}, necesitamos un parentesis de cierre en do-while."
              end
              prterr
              return true
            end
          end
        else
          if @Err == "E" then
            @Err = "No se esperaba #{@curtkn}, necesitamos un parentesis de apertura en do-while."
          end
          prterr
          if expr_search(tr2) then  #cambio de tr a tr2
            if @curtkn == ")" then
              peektkn
              return true
            else
              if @Err == "E" then
                @Err = "No se esperaba #{@curtkn}, necesitamos un parentesis de cierre en do-while."
              end
              prterr
              return true
            end
          end
        end
      end
    end
  else
    return false
  end
end

#Expresion de asignación.
def assing(tr1)
  if ident then
    if @curtkn == ":=" then
      tr = @sinCon.appendItem(tr1,":=")
      #Añadido de linea
        @sinCon.setItemData(tr,@linea)
      tr2 = @sinCon.appendItem(tr,@anttkn)
      #Añadido de linea
        @sinCon.setItemData(tr2,@linea)
      peektkn
      if expr_search(tr) then
        return true
      else
        return false
      end
    else
      if @curtkn == "++" || @curtkn == "--" then
        tr = @sinCon.appendItem(tr1,":=")
        #Añadido de linea
          @sinCon.setItemData(tr,@linea)
        if @curtkn == "++" then
          tr3 = @sinCon.appendItem(tr,@anttkn)
          #Añadido de linea
            @sinCon.setItemData(tr3,@linea)
          tr2 = @sinCon.appendItem(tr,"+")
          #Añadido de linea
            @sinCon.setItemData(tr2,@linea)
          tr5 = @sinCon.prependItem(tr2,"1")
          #Añadido de linea
            @sinCon.setItemData(tr5,@linea)
          tr4 = @sinCon.prependItem(tr2,@anttkn)
          #Añadido de linea
            @sinCon.setItemData(tr4,@linea)
        else
          tr3 = @sinCon.appendItem(tr,@anttkn)
          #Añadido de linea
            @sinCon.setItemData(tr3,@linea)
          tr2 = @sinCon.appendItem(tr,"-")
          #Añadido de linea
            @sinCon.setItemData(tr2,@linea)
          tr5 = @sinCon.prependItem(tr2,"1")
          #Añadido de linea
            @sinCon.setItemData(tr5,@linea)
          tr4 = @sinCon.prependItem(tr2,@anttkn)
          #Añadido de linea
            @sinCon.setItemData(tr4,@linea)
        end
        peektkn
        return true
      else
        if @curtkn == "+"
          if @Err == "E" then
            @Err = "No se esperaba #{@curtkn}, se esperaba el operador ++ para incrementar u otra variable."
          end
          tr = @sinCon.appendItem(tr1,"Error")
          #Añadido de linea
            @sinCon.setItemData(tr,@linea)
          tr2 = @sinCon.appendItem(tr,@anttkn)
          #Añadido de linea
            @sinCon.setItemData(tr2,@linea)
          prterr
          peektkn
          return true
        elsif @curtkn == "-"
          if @Err == "E" then
            @Err = "No se esperaba #{@curtkn}, se esperaba el operador -- para decrementar u otra variable."
          end
          tr = @sinCon.appendItem(tr1,"Error")
          #Añadido de linea
            @sinCon.setItemData(tr,@linea)
          tr2 = @sinCon.appendItem(tr,@anttkn)
          #Añadido de linea
            @sinCon.setItemData(tr2,@linea)
          prterr
          peektkn
          return true
        else
          if @Err == "E" then
            @Err = "No se esperaba #{@curtkn}, se esperaba el operador := en la asignación"
          end
          tr = @sinCon.appendItem(tr1,"Error")
          #Añadido de linea
            @sinCon.setItemData(tr,@linea)
          tr2 = @sinCon.appendItem(tr,@anttkn)
          #Añadido de linea
            @sinCon.setItemData(tr2,@linea)
          prterr
          peektkn
          if expr_search(tr) then
            return true
          else
            return false
          end
        end
      end
    end
  else
    return false
  end
end

#Expresion de while.
def whiler(tr1)
  if @curtkn == "while" then
    tr = @sinCon.appendItem(tr1, "while")
    #Añadido de linea
      @sinCon.setItemData(tr,@linea)
    peektkn
    if @curtkn == "(" then
      peektkn
      if expr_search(tr) then
        if @curtkn == ")" then
          peektkn
          if bloque("while",tr) then
            return true
          end
        else
          if @Err == "E" then
            @Err = "No se esperaba #{@curtkn}, se esperaba un parentesis de cierre en la sentencia While"
          end
          prterr
          @sinCon.setItemText(tr,"Error")
          peektkn
          if bloque("while",tr) then
            return true
          end
        end
      end
    else
      if @Err == "E" then
        @Err = "No se esperaba #{@curtkn}, se esperaba un parentesis de apertura en la sentencia while"
      end
      prterr
      if expr_search(tr) then
        if @curtkn == ")" then
          peektkn
          if bloque("while",tr) then
            return true
          end
        else
          if @Err == "E" then
            @Err = "No se esperaba #{@curtkn}, se esperaba un parentesis de cierre en la sentencia While"
          end
          prterr
          if bloque("while",tr) then
            return true
          end
        end
      end
    end
  else
    return false
  end
end

#Expresion de lectura.
def lectura(tr1)
  if @curtkn == "read" then
    tr = @sinCon.appendItem(tr1,"read")
    #Añadido de linea
      @sinCon.setItemData(tr,@linea)
    peektkn
    if ident then
      tr2 = @sinCon.appendItem(tr,@anttkn)
      #Añadido de linea
        @sinCon.setItemData(tr2,@linea)
      return true
    else
      if @Err == "E" then
        @Err = "No se esperaba #{@curtkn}, se esperaba un identificador para read."
      end
      tr2 = @sinCon.appendItem(tr,"Error")
      #Añadido de linea
        @sinCon.setItemData(tr2,@linea)
      prterr
      peektkn
      return true
    end
  else
    return false
  end
end

#Expresion de escritura.
def escritura(tr1)
  if @curtkn == "write" then
    tr = @sinCon.appendItem(tr1,"write")
    #Añadido de linea
      @sinCon.setItemData(tr,@linea)
    peektkn
    if cadena(tr)
      return true
    else
      if @Err == "E" then
        @Err = "No se esperaba #{@curtkn}, se esperaba una cadena o una cadena y expresión."
      end
      @sinCon.setItemText(tr,"Error")
      prterr
      if(@curtkn != ";") then
        peektkn
      end
      return true
    end
  else
    return false
  end
end

#Expresion de if.
def ifst(tr1)
  if @curtkn == "if" then
    tr = @sinCon.appendItem(tr1,"if")
    #Añadido de linea
      @sinCon.setItemData(tr,@linea)
    peektkn
    if @curtkn == "(" then
      peektkn
      if expr_search(tr) then
        if @curtkn == ")" then
          peektkn
          if @curtkn == "then" then
            tr2 = @sinCon.appendItem(tr,"then")
            #Añadido de linea
              @sinCon.setItemData(tr2,@linea)
            peektkn
            if bloque("if-then",tr2) then
              if @curtkn == "else" then
                tr3 = @sinCon.appendItem(tr,"else")
                #Añadido de linea
                  @sinCon.setItemData(tr3,@linea)
                peektkn
                if bloque("else",tr3) then
                  return true
                else
                  return false
                end
              else
                return true
              end
            end
          else
            if @Err == "E" then
              @Err = "No se esperaba #{@curtkn}, se esperaba un then."
            end
            tr2 = @sinCon.appendItem(tr,"Error")
            #Añadido de linea
              @sinCon.setItemData(tr2,@linea)
            prterr
            if bloque("if-then",tr2) then
              if @curtkn == "else" then
                tr3 = @sinCon.appendItem(tr,"else")
                #Añadido de linea
                  @sinCon.setItemData(tr3,@linea)
                peektkn
                if bloque("else",tr3) then
                  return true
                else
                  return false
                end
              else
                return true
              end
            end
          end
        else
          if @Err == "E" then
            @Err = "No se esperaba #{@curtkn}, se esperaba parentesis de cierre en el if."
          end
          prterr
          if @curtkn == "then" then
            tr2 = @sinCon.appendItem(tr,"then")
            #Añadido de linea
              @sinCon.setItemData(tr2,@linea)
            peektkn
            if bloque("if-then",tr2) then
              if @curtkn == "else" then
                tr3 = @sinCon.appendItem(tr,"else")
                #Añadido de linea
                  @sinCon.setItemData(tr3,@linea)
                peektkn
                if bloque("else",tr3) then
                  return true
                else
                  return false
                end
              else
                return true
              end
            end
          else
            if @Err == "E" then
              @Err = "No se esperaba #{@curtkn}, se esperaba un then."
            end
            tr2 = @sinCon.appendItem(tr,"then")
            #Añadido de linea
              @sinCon.setItemData(tr2,@linea)
            prterr
            if bloque("if-then",tr2) then
              if @curtkn == "else" then
                tr3 = @sinCon.appendItem(tr,"else")
                #Añadido de linea
                  @sinCon.setItemData(tr3,@linea)
                peektkn
                if bloque("else",tr3) then
                  return true
                else
                  return false
                end
              else
                return true
              end
            end
          end
        end
      end
    else
      if @Err == "E" then
        @Err = "No se esperaba #{@curtkn}, se esperaba parentesis de apertura en el if."
      end
      prterr
      if expr_search(tr) then
        if @curtkn == ")" then
          peektkn
          if @curtkn == "then" then
            tr2 = @sinCon.appendItem(tr,"then")
            #Añadido de linea
              @sinCon.setItemData(tr2,@linea)
            peektkn
            if bloque("if-then",tr2) then
              if @curtkn == "else" then
                tr3 = @sinCon.appendItem(tr,"else")
                #Añadido de linea
                  @sinCon.setItemData(tr3,@linea)
                peektkn
                if bloque("else",tr3) then
                  return true
                else
                  return false
                end
              else
                return true
              end
            end
          else
            if @Err == "E" then
              @Err = "No se esperaba #{@curtkn}, se esperaba un then."
            end
            tr2 = @sinCon.appendItem(tr,"Error")
            #Añadido de linea
              @sinCon.setItemData(tr2,@linea)
            prterr
            if bloque("if-then",tr2) then
              if @curtkn == "else" then
                tr3 = @sinCon.appendItem(tr,"else") #tr2
                #Añadido de linea
                  @sinCon.setItemData(tr3,@linea) #tr2
                peektkn
                if bloque("else",tr3) then
                  return true
                else
                  return false
                end
              else
                return true
              end
            end
          end
        else
          if @Err == "E" then
            @Err = "No se esperaba #{@curtkn}, se esperaba parentesis de cierre en el if."
          end
          prterr
          if @curtkn == "then" then
            tr2 = @sinCon.appendItem(tr,"then")
            #Añadido de linea
              @sinCon.setItemData(tr2,@linea)
            peektkn
            if bloque("if-then",tr2) then
              if @curtkn == "else" then
                tr3 = @sinCon.appendItem(tr,"else")
                #Añadido de linea
                  @sinCon.setItemData(tr3,@linea)
                peektkn
                if bloque("else",tr3) then
                  return true
                else
                  return false
                end
              else
                return true
              end
            end
          else
            if @Err == "E" then
              @Err = "No se esperaba #{@curtkn}, se esperaba un then."
            end
            tr2 = @sinCon.appendItem(tr,"then")
            #Añadido de linea
              @sinCon.setItemData(tr2,@linea)
            prterr
            if bloque("if-then",tr2) then
              if @curtkn == "else" then
                tr3 = @sinCon.appendItem(tr,"else")  #tr2
                #Añadido de linea
                  @sinCon.setItemData(tr3,@linea) #tr2
                peektkn
                if bloque("else",tr3) then
                  return true
                else
                  return false
                end
              else
                return true
              end
            end
          end
        end
      end
    end
  else
    return false
  end
end

def bloque (error, tr1)
  if @curtkn == "{" then
    tr = @sinCon.appendItem(tr1,"Bloque")
    #Añadido de linea
      @sinCon.setItemData(tr,@linea)
    peektkn
    if !stmtSeq(tr) then
      if @curtkn == "}" then
        peektkn
        return true
      else
        if @Err == "E" then
          @Err = "No se esperaba #{@curtkn}, el bloque #{error} necesita } para continuar."
        end
        @sinCon.setItemText(tr, "Error")
        prterr
        return true
      end
    end
  else
    if @Err == "E" then
      @Err = "No se esperaba #{@curtkn}, el bloque #{error} necesita { para empezar."
    end
    tr = @sinCon.appendItem(tr1,"Error")
    #Añadido de linea
      @sinCon.setItemData(tr,@linea)
    prterr
    if !stmtSeq(tr) then
      if @curtkn == "}" then
        peektkn
        return true
      else
        if @Err == "E" then
          @Err = "No se esperaba #{@curtkn}, el bloque #{error} necesita } para continuar."
        end
        prterr
        return true
      end
    end
  end
end

def cadena(tr1)
  if @curtkn.match("\".*\"") then
    tr = @sinCon.appendItem(tr1,@curtkn)
    #Añadido de linea
      @sinCon.setItemData(tr,@linea)
    peektkn
    if @curtkn == ","
      peektkn
      if expr_search(tr1) then
        return true
      else
        return false
      end
    elsif @curtkn == ";"
      return true
    elsif expr_search(tr1)
      if @Err == "E" then
        @Err = "No hay coma que separe la expresión de la cadena."
      end
      @sinCon.setItemText(tr1,"Error")
      prterr
      return true
    else
      return true
    end
  else
    return false
  end
end

#Tomar el siguiente token.
def peektkn
  if @id < @size then
    data = IO.readlines("metadata/Tokens.txt")[@id]
    vector = data.split(" ")
    if vector.size < 3 then
      @curtkn = data.split(" ")[0].chomp
      @linea = data.split(" ")[1].chomp
    else
      @curtkn = ""
      for i in 0..vector.size-2
        @curtkn = @curtkn.to_s+" "+vector[i].to_s
      end
      @linea = vector.last
    end
    @id = @id + 1
  else
    @curtkn = "|"
  end
end

def expr_search(tr1)
  final = 0
  if expr_decl then
    final = @id - 1
    rwntkn
    rwntkn
    rwntkn
    expr(tr1)
  else
    final = @id - 1
    rwntkn
    rwntkn
    rwntkn
    expr(tr1)
  end
  @id = final
  peektkn
end

def rwntkn
  if @id >= @limini then
    data = IO.readlines("metadata/Tokens.txt")[@id]
    vector = data.split(" ")
    if vector.size < 3 then
      @curtkn = data.split(" ")[0].chomp
      @linea = data.split(" ")[1].chomp
    else
      @curtkn = ""
      for i in 0..vector.size-2
        @curtkn = @curtkn.to_s+" "+vector[i].to_s
      end
      @linea = vector.last
    end
    @id = @id - 1
  else
    @curtkn = "|"
  end
end

#Expresion de expresiones.
def expr(tr1)
  tr = @sinCon.appendItem(tr1, "Error")
  tra = @sinCon.appendItem(tr, "Error")
  if expr_smp(tra) then
    if @curtkn == "<" || @curtkn == "=="|| @curtkn == "!=" || @curtkn == ">" || @curtkn == "<=" || @curtkn == ">=" then
      @sinCon.setItemText(tr,@curtkn)
      #Añadido de linea
        @sinCon.setItemData(tr,@linea)
      rwntkn
      tr2 = @sinCon.prependItem(tr, "Error")
      #Añadido de linea
        @sinCon.setItemData(tr2,@linea)
      if expr_smp(tr2) then
        return true
      else
        if @Err == "E" then
          @Err = "No se esperaba #{@curtkn}, se esperaba un numero o identificador en la expresión."
        end
        prterr
        return true
      end
    else
      @sinCon.moveItem(tr,tr1,tra)
      #Añadido de linea
        @sinCon.setItemData(tra,@linea)
      @sinCon.removeItem(tr)
      return true
    end
  else
    if @Err == "E" then
      @Err = "No se esperaba #{@curtkn}, se esperaba un numero o identificador en la expresión."
    end
    prterr
    if @curtkn == "<" || @curtkn == "=="|| @curtkn == "!=" || @curtkn == ">" || @curtkn == "<=" || @curtkn == ">=" then
      @sinCon.setItemText(tr1,@curtkn)
      #Añadido de linea
        @sinCon.setItemData(tr1,@linea)
      rwntkn
      tr2 = @sinCon.prependItem(tr, "Error")
      #Añadido de linea
        @sinCon.setItemData(tr2,@linea)
      if expr_smp(tr2) then
        return true
      else
        if @Err == "E" then
          @Err = "No se esperaba #{@curtkn}, se esperaba un numero o identificador en la expresión."
        end
        prterr
        return true
      end
    else
      @sinCon.moveItem(tr,tr1,tra)
      #Añadido de linea
        @sinCon.setItemData(tra,@linea)
      @sinCon.removeItem(tr)
      return true
    end
    #return false
  end
end

#Expresion de expresiones simples.
def expr_smp(tr1)
  tr = @sinCon.prependItem(tr1, "Error")
  if term(tr)
    if @curtkn == "+" || @curtkn == "-" then
      @sinCon.setItemText(tr1, @curtkn)
      rwntkn
      tr2 = @sinCon.prependItem(tr1, "Error")
      if term(tr2) then
        if @curtkn == "+" || @curtkn == "-" then
          data1 = @sinCon.getItemText(tr2)
          trb = @sinCon.prependItem(tr2, data1)
          #Añadido de linea
            @sinCon.setItemData(trb,@linea)
          if data1 == "*" || data1 == "/" || data1 == "%" then
            @sinCon.moveItem(nil,trb,tr2.first.next)
            @sinCon.moveItem(nil,trb,tr2.last)
          end
          @sinCon.setItemText(tr2, @curtkn)
          #Añadido de linea
            @sinCon.setItemData(tr2,@linea)
          rwntkn
          tr3 = @sinCon.prependItem(tr2, "Error")
          #Añadido de linea
            @sinCon.setItemData(tr3,@linea)
          expr_smp(tr3)
        else
          return true
        end
      else
        if @Err == "E" then
          @Err = "No se esperaba #{@curtkn}, se esperaba un identificador, numero o término."
        end
        prterr
        if @curtkn == "+" || @curtkn == "-" then
          data1 = @sinCon.getItemText(tr2)
          trb = @sinCon.prependItem(tr2, data1)
          #Añadido de linea
            @sinCon.setItemData(trb,@linea)
          if data1 == "*" || data1 == "/" || data1 == "%" then
            @sinCon.moveItem(nil,trb,tr2.first.next)
            @sinCon.moveItem(nil,trb,tr2.last)
          end
          @sinCon.setItemText(tr2, @curtkn)
          #Añadido de linea
            @sinCon.setItemData(tr2,@linea)
          rwntkn
          tr3 = @sinCon.prependItem(tr2, "Error")
          #Añadido de linea
            @sinCon.setItemData(tr3,@linea)
          expr_smp(tr3)
        else
          return true
        end
        #return false
      end
    else
      @sinCon.setItemText(tr1,@sinCon.getItemText(tr))
      #Añadido de linea
        @sinCon.setItemData(tr1,@linea)
      if @sinCon.itemLeaf?(tr)
        @sinCon.removeItem(tr)
      else
        @sinCon.moveItem(nil,tr1,tr.first)
        @sinCon.moveItem(nil,tr1,tr.last)
        @sinCon.removeItem(tr)
      end
      return true
    end
  else
    if @Err == "E" then
      @Err = "No se esperaba #{@curtkn}, se esperaba un identificador, numero o término."
    end
    prterr
    if @curtkn == "+" || @curtkn == "-" then
      @sinCon.setItemText(tr1, @curtkn)
      rwntkn
      tr2 = @sinCon.prependItem(tr1, "Error")
      if term(tr2) then
        if @curtkn == "+" || @curtkn == "-" then
          #trb = @sinCon.appendItem(tr2, @anttkn)
          trb = @sinCon.prependItem(tr2, @anttkn)
          if @anttkn == "*" || @anttkn == "/" || @anttkn == "%" then
            @sinCon.moveItem(nil,trb,tr2.first.next)
            @sinCon.moveItem(nil,trb,tr2.last)
          end
          @sinCon.setItemText(tr2, @curtkn)
          #Añadido de linea
            @sinCon.setItemData(tr2,@linea)
          rwntkn
          tr3 = @sinCon.prependItem(tr2, "Error")
          expr_smp(tr3)
        else
          return true
        end
      else
        if @Err == "E" then
          @Err = "No se esperaba #{@curtkn}, se esperaba un identificador, numero o término."
        end
        prterr
        if @curtkn == "+" || @curtkn == "-" then
          trb = @sinCon.prependItem(tr2, @anttkn)
          if @anttkn == "*" || @anttkn == "/" || @anttkn == "%" then
            @sinCon.moveItem(nil,trb,tr2.first.next)
            @sinCon.moveItem(nil,trb,tr2.last)
          end
          @sinCon.setItemText(tr2, @curtkn)
          #Añadido de linea
            @sinCon.setItemData(tr2,@linea)
          rwntkn
          tr3 = @sinCon.prependItem(tr2, "Error")
          expr_smp(tr3)
        else
          return true
        end
        #return false
      end
    else
      @sinCon.setItemText(tr1,@sinCon.getItemText(tr))
      #Añadido de linea
        @sinCon.setItemData(tr1,@linea)
      if @sinCon.itemLeaf?(tr)
        @sinCon.removeItem(tr)
      else
        @sinCon.moveItem(nil,tr1,tr.first)
        @sinCon.moveItem(nil,tr1,tr.last)
        @sinCon.removeItem(tr)
      end
      return true
    end
    #return false
  end
end

#Expresion de Terminos
def term(tr1)
  tr = @sinCon.prependItem(tr1, "Error")
  if factor(tr)
    if @curtkn == "*" || @curtkn == "/" || @curtkn == "%" then
      @sinCon.setItemText(tr1, @curtkn)
      rwntkn
      tk = @sinCon.prependItem(tr1, "Error")
      if factor(tk) then
        if @curtkn == "*" || @curtkn == "/" || @curtkn == "%" then
          trc = @sinCon.prependItem(tk, @anttkn)
          #Añadido de linea
            @sinCon.setItemData(trc,@linea)
          @sinCon.setItemText(tk, @curtkn)
          #Añadido de linea
            @sinCon.setItemData(tk,@linea)
          rwntkn
          tr4 = @sinCon.prependItem(tk, "Error")
          term(tr4)
        else
          return true
        end
      else
        if @Err == "E" then
          @Err = "No se esperaba #{@curtkn}, se esperaba un identificador, número o termino."
        end
        prterr
        if @curtkn == "*" || @curtkn == "/" || @curtkn == "%" then
          trc = @sinCon.prependItem(tk, @anttkn)
          #Añadido de linea
            @sinCon.setItemData(trc,@linea)
          @sinCon.setItemText(tk, @curtkn)
          #Añadido de linea
            @sinCon.setItemData(tk,@linea)
          rwntkn
          tr4 = @sinCon.prependItem(tk, "Error")
          term(tr4)
        else
          return true
        end
        #return false
      end
    else
      @sinCon.setItemText(tr1,@anttkn)
      #Añadido de linea
        @sinCon.setItemData(tr1,@linea)
      @sinCon.removeItem(tr)
      return true
    end
  else
    if @Err == "E" then
      @Err = "No se esperaba #{@curtkn}, se esperaba un identificador, número o termino."
    end
    prterr
    if @curtkn == "*" || @curtkn == "/" || @curtkn == "%" then
      @sinCon.setItemText(tr1, @curtkn)
      rwntkn
      tk = @sinCon.prependItem(tr1, "Error")
      if factor(tk) then
        if @curtkn == "*" || @curtkn == "/" || @curtkn == "%" then
          trc = @sinCon.prependItem(tk, @anttkn)
          #Añadido de linea
            @sinCon.setItemData(trc,@linea)
          @sinCon.setItemText(tk, @curtkn)
          #Añadido de linea
            @sinCon.setItemData(tk,@linea)
          rwntkn
          tr4 = @sinCon.prependItem(tk, "Error")
          term(tr4)
        else
          return true
        end
      else
        if @Err == "E" then
          @Err = "No se esperaba #{@curtkn}, se esperaba un identificador, número o término."
        end
        prterr
        if @curtkn == "*" || @curtkn == "/" || @curtkn == "%" then
          trc = @sinCon.prependItem(tk, @anttkn)
          #Añadido de linea
            @sinCon.setItemData(trc,@linea)
          @sinCon.setItemText(tk, @curtkn)
          #Añadido de linea
            @sinCon.setItemData(tk,@linea)
          rwntkn
          tr4 = @sinCon.prependItem(tk, "Error")
          term(tr4)
        else
          return true
        end
        #return false
      end
    else
      @sinCon.setItemText(tr1,@anttkn)
      #Añadido de linea
        @sinCon.setItemData(tr1,@linea)
      @sinCon.removeItem(tr)
      return true
    end
    #return false
  end
end

#Expresion de factores.
def factor(tr1)
  if @curtkn == ")"
    rwntkn
    if expr(tr1) then
      @sinCon.moveItem(tr1,tr1.parent,tr1.first)
      @sinCon.removeItem(tr1)
      if @curtkn == "(" then
        rwntkn
        return true
      else
        if @Err == "E" then
          @Err = "No se esperaba #{@curtkn}, se esperaba ) para el factor."
        end
        @sinCon.setItemText(tr1,"Error")
        prterr
        return true
      end
    else
      return false
    end
  elsif num
    @anttkn = @curtkn
    @sinCon.setItemText(tr1,@curtkn)
    #Añadido de linea
      @sinCon.setItemData(tr1,@linea)
    rwntkn
    return true
  elsif ident_decl
    @sinCon.setItemText(tr1,@anttkn)
    #Añadido de linea
      @sinCon.setItemData(tr1,@linea)
    return true
  else
    return false
  end
end

#Expresion de expresiones.
def expr_decl
  if expr_smp_decl then
    if @curtkn == "<" || @curtkn == "=="|| @curtkn == "!=" || @curtkn == ">" || @curtkn == "<=" || @curtkn == ">=" then
      peektkn
      if expr_smp_decl then
        return true
      else
        return true
      end
    else
      return true
    end
  else
    if @curtkn == "<" || @curtkn == "=="|| @curtkn == "!=" || @curtkn == ">" || @curtkn == "<=" || @curtkn == ">=" then
      peektkn
      if expr_smp_decl then
        return true
      else
        return true
      end
    else
      return true
    end
  end
end

#Expresion de expresiones simples.
def expr_smp_decl
  if term_decl
    if @curtkn == "+" || @curtkn == "-" then
      peektkn
      if term_decl then
        if @curtkn == "+" || @curtkn == "-" then
          peektkn
          expr_smp_decl
        else
          return true
        end
      end
    else
      return true
    end
  end
end

#Expresion de Terminos
def term_decl
  if factor_decl
    if @curtkn == "*" || @curtkn == "/" || @curtkn == "%" then
      peektkn
      if factor_decl then
        if @curtkn == "*" || @curtkn == "/" || @curtkn == "%" then
          peektkn
          term_decl
        else
          return true
        end
      else
        if @curtkn == "*" || @curtkn == "/" || @curtkn == "%" then
          peektkn
          term_decl
        else
          return true
        end
      end
    else
      return true
    end
  else
    if @curtkn == "*" || @curtkn == "/" || @curtkn == "%" then
      peektkn
      if factor_decl then
        if @curtkn == "*" || @curtkn == "/" || @curtkn == "%" then
          peektkn
          term_decl
        else
          return true
        end
      else
        if @curtkn == "*" || @curtkn == "/" || @curtkn == "%" then
          peektkn
          term_decl
        else
          return true
        end
      end
    else
      return true
    end
  end
end

#Expresion de factores.
def factor_decl
  if @curtkn == "("
    peektkn
    if expr_decl then
      if @curtkn == ")" then
        peektkn
        return true
      else
        return true
      end
    else
      return false
    end
  elsif num
    @anttkn = @curtkn
    peektkn
    return true
  elsif ident
    return true
  else
    return false
  end
end

def analizadorLexico
  @lexCon.clearItems
  @errCon.clearItems
  reservadas = %w[main if then else end do while repeat until float read write cout real integer bool]
  letras = %w[a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z]
  numeros = %w[0 1 2 3 4 5 6 7 8 9]
  token = ""
  col = 1
  File.write("metadata/changes.txt",@texto.text)
  entrada = File.open("metadata/changes.txt", 'r')
  salida = File.open("metadata/Tokens.txt", 'w')
  while linea = entrada.gets()
    i = 0
    while i < linea.length
      token = ""
      if(letras.find_index(linea[i]))
        token += linea[i]
        i += 1
        while letras.find_index(linea[i]) || numeros.find_index(linea[i]) || linea[i]=="_"
          token += linea[i]
          i += 1
        end
        if reservadas.find_index(token)
          @lexCon.appendItem (token + "   Palabra reservada")
          salida.puts (token +" "+col.to_s)
        else
          @lexCon.appendItem (token + "   identificador")
          salida.puts (token +" "+col.to_s)
        end
      elsif (numeros.find_index(linea[i]))
        entero = true
        token += linea[i]
        punto = 0
        i += 1
        while numeros.find_index(linea[i]) || linea[i]=='.'
          if(linea[i]=='.')
            if(punto==0)
              entero = false
              token += linea[i]
              i += 1
              if(numeros.find_index(linea[i]))
                token += linea[i]
                i += 1
                while numeros.find_index(linea[i])
                  token += linea[i]
                  i += 1
                end
              end
              punto += 1
            end
            break
          elsif (numeros.find_index(linea[i]))
            token += linea[i]
            i += 1
            while numeros.find_index(linea[i])
              token += linea[i]
              i += 1
            end
          end
        end
        if entero
          @lexCon.appendItem (token + "   Numero Entero")
          salida.puts (token +" "+col.to_s)
        else
          @lexCon.appendItem (token + "   Numero Decimal")
          salida.puts (token +" "+col.to_s)
        end
      elsif (linea[i] == '/')
        token += linea[i]
        i += 1
        if (linea[i] == '/')
          #@lexCon.appendItem (token + "/   Comentario")
          i+=1
          while linea[i] != "\n" && linea[i] != nil
            i += 1
          end
        elsif (linea[i] == '*')
          #@lexCon.appendItem (token + "*   Comentario Multilinea")
          i += 1
          comMul = true
          while comMul
            if (linea[i] == '*' && linea[i+1] == '/')
              #@lexCon.appendItem ("*/   Fin Coment. Multi")
              i += 2
              comMul = false
            elsif (linea[i] == "\n")
              linea = entrada.gets()
              col += 1
              i = 0
            else
              i += 1
            end
          end
        else
          #token += linea[i]
          #i += 1
          @lexCon.appendItem (token + "   Division")
          salida.puts (token +" "+col.to_s)
        end
      elsif (linea[i]=='"')
        token += linea[i]
        i += 1
        while linea[i] != '"' && linea[i] != nil
          if (linea[i] == "\n")
            linea = entrada.gets()
            col += 1
            i = 0
          else
            token += linea[i]
            i += 1
          end
        end
        if (linea[i]=='"')
          token += linea[i]
          i += 1
        end
        @lexCon.appendItem (token + "   Cadena")
        salida.puts (token +" "+col.to_s)
      elsif (linea[i]=='+')
        token += linea[i]
        i += 1
        if (linea[i]=='+')
          token += linea[i]
          i += 1
          @lexCon.appendItem (token + "   Incremento")
          salida.puts (token +" "+col.to_s)
        else
          @lexCon.appendItem (token + "   Adicion")
          salida.puts (token +" "+col.to_s)
        end
      elsif (linea[i]=='-')
        token += linea[i]
        i += 1
        if (linea[i]=='-')
          token += linea[i]
          i += 1
          @lexCon.appendItem (token + "   Decremento")
          salida.puts (token +" "+col.to_s)
        else
          @lexCon.appendItem (token + "   Substraccion")
          salida.puts (token +" "+col.to_s)
        end
      elsif (linea[i]=='<')
        token += linea[i]
        i += 1
        if (linea[i]=='=')
          token += linea[i]
          i += 1
          @lexCon.appendItem (token + "   Menor igual")
          salida.puts (token +" "+col.to_s)
        else
          @lexCon.appendItem (token + "   Menor que")
          salida.puts (token +" "+col.to_s)
        end
      elsif (linea[i]=='>')
        token += linea[i]
        i += 1
        if (linea[i]=='=')
          token += linea[i]
          i += 1
          @lexCon.appendItem (token + "   Mayor igual")
          salida.puts (token +" "+col.to_s)
        else
          @lexCon.appendItem (token + "   Mayor que")
          salida.puts (token +" "+col.to_s)
        end
      elsif (linea[i]=='=')
        token += linea[i]
        i += 1
        if (linea[i]=='=')
          token += linea[i]
          i += 1
          @lexCon.appendItem (token + "   Comparacion")
          salida.puts (token +" "+col.to_s)
        else
          @errCon.appendItem (token + "   Error   Ln: #{col} Col: #{i}")
          salida.puts (token +" "+col.to_s)
        end
      elsif (linea[i]=='!')
        token += linea[i]
        i += 1
        if (linea[i]=='=')
          token += linea[i]
          i += 1
          @lexCon.appendItem (token + "   Diferente")
          salida.puts (token +" "+col.to_s)
        else
          @errCon.appendItem (token + "   Error   Ln: #{col} Col: #{i}")
        end
      elsif (linea[i] == ':')
        token += linea[i]
        i += 1
        if (linea[i] == '=')
          token += linea[i]
          i += 1
          @lexCon.appendItem (token + "   Asignacion")
          salida.puts (token +" "+col.to_s)
        else
          @errCon.appendItem (token + "   Error   Ln: #{col} Col: #{i}")
        end
      elsif (linea[i] == ';')
        token += linea[i]
        i += 1
        @lexCon.appendItem (token + "   Delimitador")
        salida.puts (token +" "+col.to_s)
      elsif (linea[i] == ',')
        token += linea[i]
        i += 1
        @lexCon.appendItem (token + "   Delimitador")
        salida.puts (token +" "+col.to_s)
      elsif (linea[i] == '%')
        token += linea[i]
        i += 1
        @lexCon.appendItem (token + "   Modulo")
        salida.puts (token +" "+col.to_s)
      elsif (linea[i] == '(')
        token += linea[i]
        i += 1
        @lexCon.appendItem (token + "   Parentesis que abre")
        salida.puts (token +" "+col.to_s)
      elsif (linea[i] == ')')
        token += linea[i]
        i += 1
        @lexCon.appendItem (token + "   Parentesis que cierra")
        salida.puts (token +" "+col.to_s)
      elsif (linea[i] == '{')
        token += linea[i]
        i += 1
        @lexCon.appendItem (token + "   Llave que abre")
        salida.puts (token +" "+col.to_s)
      elsif (linea[i] == '}')
        token += linea[i]
        i += 1
        @lexCon.appendItem (token + "   Llave que cierra")
        salida.puts (token +" "+col.to_s)
      elsif (linea[i] == '*')
        token += linea[i]
        i += 1
        @lexCon.appendItem (token + "   Mutiplicacion")
        salida.puts (token +" "+col.to_s)
      elsif (linea[i] == " ")
        i += 1
      elsif (linea[i] == "\n")
        i += 1
      elsif (linea[i] == "\t")
        i += 1
      else
        token += linea[i]
        i += 1
        @errCon.appendItem (token + "   Error   Ln: #{col} Col: #{i}")
      end
    end
    col += 1
  end
  salida.close
end

def copyTree(nodo,ref)
  if nodo != nil
    flr = @semCon.appendItem(ref,@sinCon.getItemText(nodo))
    @semCon.setItemData(flr, @sinCon.getItemData(nodo))
    prox = nodo.next
    if prox != nil
      copyTree(prox,ref)
    end
    copyTree(nodo.first,flr)
  end
end

#-----------------------------------Analizador Semantico--------------------------------------

def semanticAnalize(nodo)
  if nodo != nil
    operator = @semCon.getItemText(nodo)
    if operator == ":="
      semanticAnalize(nodo.first)
      nombre = @semCon.getItemText(nodo.first)
      data = @semCon.getItemData(nodo.first).getType
      semanticAnalize(nodo.last)
      val1 = @semCon.getItemData(nodo.last).getValue
      typ1 = @semCon.getItemData(nodo.last).getType
      if data == typ1
        if @symbotable[nombre.to_s] != 0
          #Añadidura para secuencias de variables
            nodeSeq = @symbotable[nombre.to_s].getSequ
            @symbotable[nombre.to_s] = SymboTab.new(nombre.to_s,typ1,val1,nodeSeq)
          @semCon.setItemData(nodo, DataTyper.new(typ1,val1))
        else
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          @semCon.setItemText(nodo, "Error")
        end
      elsif data == "float" && typ1 == "integer"
        if @symbotable[nombre.to_s] != 0
          #Añadidura para secuencias de variables
            nodeSeq = @symbotable[nombre.to_s].getSequ
            @symbotable[nombre.to_s] = SymboTab.new(nombre.to_s,data,val1.to_f,nodeSeq)
          @semCon.setItemData(nodo, DataTyper.new(data.to_s,val1.to_f))
        else
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          @semCon.setItemText(nodo, "Error")
        end
      elsif data == "bool" && typ1 == "integer"
        if val1 == 1
          if @symbotable[nombre.to_s] != 0
            #Añadidura para secuencias de variables
            nodeSeq = @symbotable[nombre.to_s].getSequ
            @symbotable[nombre.to_s] = SymboTab.new(nombre.to_s,data,"true",nodeSeq)
            @semCon.setItemData(nodo, DataTyper.new(data,"true"))
          else
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
            @semCon.setItemText(nodo, "Error")
          end
        elsif val1 == 0
          if @symbotable[nombre.to_s] != 0
            #Añadidura para secuencias de variables
            nodeSeq = @symbotable[nombre.to_s].getSequ
            @symbotable[nombre.to_s] = SymboTab.new(nombre.to_s,data,"false",nodeSeq)
            @semCon.setItemData(nodo, DataTyper.new(data,"false"))
          else
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
            @semCon.setItemText(nodo, "Error")
          end
        else
          @errCon.appendItem("El valor [ "+val1.to_s+" ] no puede entenderse como booleano, linea: "+@semCon.getItemData(nodo).to_s)
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          @semCon.setItemText(nodo, "Error")
        end
      else
        @errCon.appendItem("El tipo [ "+typ1+" ] no puede promoverse a [ "+data+" ], linea: "+@semCon.getItemData(nodo).to_s)
        if @symbotable[nombre.to_s] != 0
          #Añadidura para secuencias de variables (Esto solo es para que aparezcan los elementos aun en error)
            nodeSeq = @symbotable[nombre.to_s].getSequ
            @symbotable[nombre.to_s] = SymboTab.new(nombre.to_s,data,val1.to_f,nodeSeq)
            @semCon.setItemData(nodo, DataTyper.new(data,val1.to_i))
        else
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          @semCon.setItemText(nodo, "Error")
        end
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == "+"
      semanticAnalize(nodo.first)
      izq = @semCon.getItemData(nodo.first)
      val1 = izq.getValue
      typ1 = izq.getType
      semanticAnalize(nodo.last)
      der = @semCon.getItemData(nodo.last)
      val2 = der.getValue
      typ2 = der.getType
      if typ1 == typ2
        if val1 == nil
          #@errCon.appendItem("[ "+@semCon.getItemText(nodo.first)+" ] es nulo, linea: "+@semCon.getItemData(nodo).to_s)
          errLine(@semCon.getItemText(nodo.first),nodo,0)
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        elsif val2 == nil
          #@errCon.appendItem("[ "+@semCon.getItemText(nodo.last)+" ] es nulo, linea: "+@semCon.getItemData(nodo).to_s)
          errLine(@semCon.getItemText(nodo.last),nodo,0)
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        else
          @semCon.setItemData(nodo, DataTyper.new(typ1,val1+val2))
        end
      else
        if (typ1 == "float" && typ2 == "integer") || (typ2 == "float" && typ1 == "integer")
          if val1 == nil
            #@errCon.appendItem("[ "+@semCon.getItemText(nodo.first)+" ] es nulo, linea: "+@semCon.getItemData(nodo).to_s)
            errLine(@semCon.getItemText(nodo.first),nodo,0)
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          elsif val2 == nil
            #@errCon.appendItem("[ "+@semCon.getItemText(nodo.last)+" ] es nulo, linea: "+@semCon.getItemData(nodo).to_s)
            errLine(@semCon.getItemText(nodo.last),nodo,0)
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          else
            @semCon.setItemData(nodo, DataTyper.new("float",val1+val2))
          end
        else
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        end
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == "-"
      semanticAnalize(nodo.first)
      izq = @semCon.getItemData(nodo.first)
      val1 = izq.getValue
      typ1 = izq.getType
      semanticAnalize(nodo.last)
      der = @semCon.getItemData(nodo.last)
      val2 = der.getValue
      typ2 = der.getType
      if typ1 == typ2
        if val1 == nil
          errLine(@semCon.getItemText(nodo.first),nodo,0)
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        elsif val2 == nil
          errLine(@semCon.getItemText(nodo.last),nodo,0)
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        else
          @semCon.setItemData(nodo, DataTyper.new(typ1,val1-val2))
        end
      else
        if (typ1 == "float" && typ2 == "integer") || (typ2 == "float" && typ1 == "integer")
          if val1 == nil
            errLine(@semCon.getItemText(nodo.first),nodo,0)
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          elsif val2 == nil
            errLine(@semCon.getItemText(nodo.last),nodo,0)
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          else
            @semCon.setItemData(nodo, DataTyper.new("float",val1-val2))
          end
        else
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        end
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == "*"
      semanticAnalize(nodo.first)
      izq = @semCon.getItemData(nodo.first)
      val1 = izq.getValue
      typ1 = izq.getType
      semanticAnalize(nodo.last)
      der = @semCon.getItemData(nodo.last)
      val2 = der.getValue
      typ2 = der.getType
      if typ1 == typ2
        if val1 == nil
          errLine(@semCon.getItemText(nodo.first),nodo,0)
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        elsif val2 == nil
          errLine(@semCon.getItemText(nodo.last),nodo,0)
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        else
          @semCon.setItemData(nodo, DataTyper.new(typ1,val1*val2))
        end
      else
        if (typ1 == "float" && typ2 == "integer") || (typ2 == "float" && typ1 == "integer")
          if val1 == nil
            errLine(@semCon.getItemText(nodo.first),nodo,0)
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          elsif val2 == nil
            errLine(@semCon.getItemText(nodo.last),nodo,0)
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          else
            @semCon.setItemData(nodo, DataTyper.new("float",val1*val2))
          end
        else
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        end
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == "/"
      semanticAnalize(nodo.first)
      izq = @semCon.getItemData(nodo.first)
      val1 = izq.getValue
      typ1 = izq.getType
      semanticAnalize(nodo.last)
      der = @semCon.getItemData(nodo.last)
      val2 = der.getValue
      typ2 = der.getType
      if typ1 == typ2
        if val1 == nil
          errLine(@semCon.getItemText(nodo.first),nodo,0)
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        elsif val2 == nil
          errLine(@semCon.getItemText(nodo.last),nodo,0)
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        else
          if val2 != 0
            @semCon.setItemData(nodo, DataTyper.new(typ1,val1/val2))
          else
            errLine("",nodo,2)
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          end
        end
      else
        if (typ1 == "float" && typ2 == "integer") || (typ2 == "float" && typ1 == "integer")
          if val1 == nil
            errLine(@semCon.getItemText(nodo.first),nodo,0).to_s
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          elsif val2 == nil
            errLine(@semCon.getItemText(nodo.last),nodo,0)
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          else
            if val2 != 0
              @semCon.setItemData(nodo, DataTyper.new("float",val1/val2))
            else
              errLine("",nodo,2)
              @semCon.setItemData(nodo, DataTyper.new("Error",nil))
            end
          end
        else
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        end
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == "%"
      semanticAnalize(nodo.first)
      izq = @semCon.getItemData(nodo.first)
      val1 = izq.getValue
      typ1 = izq.getType
      semanticAnalize(nodo.last)
      der = @semCon.getItemData(nodo.last)
      val2 = der.getValue
      typ2 = der.getType
      if typ1 == typ2
        if val1 == nil
          errLine(@semCon.getItemText(nodo.first),nodo,0) #.to_s
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        elsif val2 == nil
          errLine(@semCon.getItemText(nodo.last),nodo,0)
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        else
          @semCon.setItemData(nodo, DataTyper.new(typ1,val1%val2))
        end
      else
        if (typ1 == "float" && typ2 == "integer") || (typ2 == "float" && typ1 == "integer")
          if val1 == nil
            errLine(@semCon.getItemText(nodo.first),nodo,0)
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          elsif val2 == nil
            errLine(@semCon.getItemText(nodo.last),nodo,0)
            @semCon.setItemData(nodo, DataTyper.new("Error",nil))
          else
            @semCon.setItemData(nodo, DataTyper.new("float",val1%val2))
          end
        else
          @semCon.setItemData(nodo, DataTyper.new("Error",nil))
        end
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == "declaracion"
      brother = nodo.first.next
      tipo = @semCon.getItemText(nodo.first)
      declarations(brother,tipo)
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == "=="
      semanticAnalize(nodo.first)
      val1 = @semCon.getItemData(nodo.first).getValue
      semanticAnalize(nodo.last)
      val2 = @semCon.getItemData(nodo.last).getValue
      if val1 == nil
        errLine(@semCon.getItemText(nodo.first),nodo,0)
        @semCon.setItemData(nodo, DataTyper.new("Error",nil))
      elsif val2 == nil
        errLine(@semCon.getItemText(nodo.last),nodo,0)
        @semCon.setItemData(nodo, DataTyper.new("Error",nil))
      else
        if val1 == val2 then
          @semCon.setItemData(nodo, DataTyper.new("bool",true))
        else
          @semCon.setItemData(nodo, DataTyper.new("bool",false))
        end
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == ">="
      semanticAnalize(nodo.first)
      val1 = @semCon.getItemData(nodo.first).getValue
      semanticAnalize(nodo.last)
      val2 = @semCon.getItemData(nodo.last).getValue
      if val1 == nil
        errLine(@semCon.getItemText(nodo.first),nodo,0)
        @semCon.setItemData(nodo, DataTyper.new("Error",nil))
      elsif val2 == nil
        errLine(@semCon.getItemText(nodo.last),nodo,0)
        @semCon.setItemData(nodo, DataTyper.new("Error",nil))
      else
        if val1 >= val2 then
          @semCon.setItemData(nodo, DataTyper.new("bool",true))
        else
          @semCon.setItemData(nodo, DataTyper.new("bool",false))
        end
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == "<="
      semanticAnalize(nodo.first)
      val1 = @semCon.getItemData(nodo.first).getValue
      semanticAnalize(nodo.last)
      val2 = @semCon.getItemData(nodo.last).getValue
      if val1 <= val2 then
        @semCon.setItemData(nodo, DataTyper.new("bool",true))
      else
        @semCon.setItemData(nodo, DataTyper.new("bool",false))
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == ">"
      semanticAnalize(nodo.first)
      val1 = @semCon.getItemData(nodo.first).getValue
      semanticAnalize(nodo.last)
      val2 = @semCon.getItemData(nodo.last).getValue
      if val1 == nil
        errLine(@semCon.getItemText(nodo.first),nodo,0)
        @semCon.setItemData(nodo, DataTyper.new("Error",nil))
      elsif val2 == nil
        errLine(@semCon.getItemText(nodo.last),nodo,0)
        @semCon.setItemData(nodo, DataTyper.new("Error",nil))
      else
        if val1 > val2 then
          @semCon.setItemData(nodo, DataTyper.new("bool",true))
        else
          @semCon.setItemData(nodo, DataTyper.new("bool",false))
        end
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == "<"
      semanticAnalize(nodo.first)
      val1 = @semCon.getItemData(nodo.first).getValue
      semanticAnalize(nodo.last)
      val2 = @semCon.getItemData(nodo.last).getValue
      if val1 == nil
        errLine(@semCon.getItemText(nodo.first),nodo,0)
        @semCon.setItemData(nodo, DataTyper.new("Error",nil))
      elsif val2 == nil
        errLine(@semCon.getItemText(nodo.last),nodo,0)
        @semCon.setItemData(nodo, DataTyper.new("Error",nil))
      else
        if val1 < val2 then
          @semCon.setItemData(nodo, DataTyper.new("bool",true))
        else
          @semCon.setItemData(nodo, DataTyper.new("bool",false))
        end
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == "!="
      semanticAnalize(nodo.first)
      val1 = @semCon.getItemData(nodo.first).getValue
      semanticAnalize(nodo.last)
      val2 = @semCon.getItemData(nodo.last).getValue
      if val1 == nil
        errLine(@semCon.getItemText(nodo.first),nodo,0)
        @semCon.setItemData(nodo, DataTyper.new("Error",nil))
      elsif val2 == nil
        errLine(@semCon.getItemText(nodo.last),nodo,0)
        @semCon.setItemData(nodo, DataTyper.new("Error",nil))
      else
        if val1 != val2 then
          @semCon.setItemData(nodo, DataTyper.new("bool",true))
        else
          @semCon.setItemData(nodo, DataTyper.new("bool",false))
        end
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    elsif operator == "write"
      nod = nodo.first
      if nod != nil
        @semCon.setItemData(nodo.first, DataTyper.new("cadena",@semCon.getItemText(nod).to_s))
        if nod.next != nil
          semanticAnalize(nod.next)
          tipo = @semCon.getItemData(nod.next).getType
          if tipo != "integer" && tipo != "float"
            @errCon.appendItem("La expresión en write no es float o integer, linea: "+@semCon.getItemData(nodo).to_s)
            @semCon.setItemData(nodo, DataTyper.new("Error","Error"))
          else
            valor = @semCon.getItemData(nod.next).getValue
            cRs = @semCon.getItemText(nod)
            @semCon.setItemData(nodo, DataTyper.new("cadena",cRs[0,cRs.length-1]+valor.to_s+"\""))
          end
        else
          @semCon.setItemData(nodo, DataTyper.new("cadena",@semCon.getItemText(nod).to_s))
        end
      else
        @semCon.setItemData(nodo, DataTyper.new("cadena",@semCon.getItemText(nod)))
      end
      #Buscamaos nuevos nodos que evaluar
        semanticAnalize(nodo.next)
    elsif operator == "then" || operator == "do" || operator == "Bloque"
      semanticAnalize(nodo.first)
      semanticAnalize(nodo.next)
    elsif operator == "else" || operator == "Error" || operator == "main"
      semanticAnalize(nodo.first)
    elsif operator == "read"
      semanticAnalize(nodo.next)
    elsif operator == "if"
      semanticAnalize(nodo.first)
      if @semCon.getItemData(nodo.first).getType != "bool"
        @errCon.appendItem("La expresión dentro del if no es booleana, linea: "+@semCon.getItemData(nodo).to_s)
      end
      #Buscamaos nuevos nodos que evaluar
        semanticAnalize(nodo.next)
    elsif operator == "until"
      semanticAnalize(nodo.first)
      if @semCon.getItemData(nodo.first).getType != "bool"
        @errCon.appendItem("La expresión dentro del until no es booleana, linea: "+@semCon.getItemData(nodo).to_s)
      end
      #Buscamaos nuevos nodos que evaluar
        semanticAnalize(nodo.next)
    elsif operator == "while"
      semanticAnalize(nodo.first)
      if @semCon.getItemData(nodo.first).getType != "bool"
        @errCon.appendItem("La expresión dentro del while no es booleana, linea: "+@semCon.getItemData(nodo).to_s)
      end
      #Buscamaos nuevos nodos que evaluar
      semanticAnalize(nodo.next)
    else
      semanticAnalize(nodo.first)
      semanticAnalize(nodo.next)
      if isInteger(operator)
        @semCon.setItemData(nodo,DataTyper.new("integer", operator.to_i))
      elsif isFloat(operator)
        @semCon.setItemData(nodo,DataTyper.new("float", operator.to_f))
      else
        nodeData = @symbotable[operator.to_s]
        if nodeData != 0
          #Añadidura para secuencias de variables
           if isInteger(@semCon.getItemData(nodo).to_s)
            sequen = nodeData.getSequ << @semCon.getItemData(nodo).to_s
           else
             sequen = nodeData.getSequ
           end
          @semCon.setItemData(nodo,DataTyper.new(nodeData.getType,nodeData.getValue))
            @symbotable[operator.to_s] =  SymboTab.new(operator.to_s,nodeData.getType,nodeData.getValue,sequen)
        else
          errLine(operator,nodo,1)
          @semCon.setItemData(nodo,DataTyper.new("Error",nil))
        end
      end
    end
  end
end

def isInteger(val)
  true if Integer(val) rescue false
end

def isFloat(val)
  true if Float(val) rescue false
end

def declarations(node,tipo)
  if node != nil
    nombre = @semCon.getItemText(node)
    if @symbotable[nombre.to_s] == 0
      sequ = [@semCon.getItemData(node)]
      #Añadidura para secuencias de variables
        @symbotable[nombre.to_s] = SymboTab.new(nombre.to_s,tipo,nil,sequ)
      @semCon.setItemData(node,DataTyper.new(tipo,nil))
      declarations(node.next,tipo)
    else
      @errCon.appendItem("El identificador [ "+nombre+" ] ya fue definido antes, linea: "+@semCon.getItemData(node).to_s)
      declarations(node.next,tipo)
    end
  end
end

#---------------------------------Función para escritura de errores Semanticos----------------------------------

def errLine(nodr,nodl,typ)
  val = @semCon.getItemData(nodl)
  if isInteger(val)
    if typ == 0
      @errCon.appendItem("[ "+nodr+" ] es nulo, linea: "+val.to_s)
    elsif typ == 1
      @errCon.appendItem("La variable [ "+nodr+" ] no fue declarada, linea: "+val.to_s)
    else
      @errCon.appendItem("La división entre cero no es válida, linea: "+val.to_s)
    end
  end
end

#------------------Funcion para reemplazo de nombre de nodos por sus respectivos valores y tipos de dato----------------

def changer(data)
  if data != nil
    if !@semCon.getItemData(data).is_a?(String)
      nombre = @semCon.getItemText(data)
      @semCon.setItemText(data,nombre+" ["+@semCon.getItemData(data).getValue.to_s+","+@semCon.getItemData(data).getType+"]")
    end
    changer(data.next)
    changer(data.first)
  end
end

#---------------------------------Función de generación de codigo Intermedio------------------------------------

def pCode(nodo)
  if nodo != nil
    slip = @sinCon.getItemText(nodo).split(" ")
    operator = slip[0]
    typ = slip[1]
    if operator == "+"
      pCode(nodo.first)
      pCode(nodo.last)
      @intCon.appendItem("ADI")
    elsif operator == "-"
      pCode(nodo.first)
      pCode(nodo.last)
      @intCon.appendItem("SBI")
    elsif operator == "*"
      pCode(nodo.first)
      pCode(nodo.last)
      if typ["float"] != nil then
        @intCon.appendItem("MPR")
      else
        @intCon.appendItem("MPI")
      end
    elsif operator == "/"
      pCode(nodo.first)
      pCode(nodo.last)
      if typ["float"] != nil then
        @intCon.appendItem("DIV")
      else
        @intCon.appendItem("DVI")
      end
    elsif operator == "%"
      pCode(nodo.first)
      pCode(nodo.last)
      @intCon.appendItem("MOD")
    elsif operator == ":="
      @intCon.appendItem("LDA "+@semCon.getItemText(nodo.first).split(" ")[0])
      pCode(nodo.last)
      @intCon.appendItem("STO")
      pCode(nodo.next)
    elsif isFloat(operator)
      @intCon.appendItem("LDC " + operator)
    elsif operator == "=="
      pCode(nodo.first)
      pCode(nodo.last)
      @intCon.appendItem("EQU")
    elsif operator == "!="
      pCode(nodo.first)
      pCode(nodo.last)
      @intCon.appendItem("NEQ")
    elsif operator == ">"
      pCode(nodo.first)
      pCode(nodo.last)
      @intCon.appendItem("GRT")
    elsif operator == "<"
      pCode(nodo.first)
      pCode(nodo.last)
      @intCon.appendItem("LRT")
    elsif operator == ">="
      pCode(nodo.first)
      pCode(nodo.last)
      @intCon.appendItem("GEQ")
    elsif operator == "<="
      pCode(nodo.first)
      pCode(nodo.last)
      @intCon.appendItem("LEQ")
    elsif operator == "if"
      lb = @labeler
      fnodo = nodo.first
      pCode(fnodo)
      lnodo = nodo.last
      @intCon.appendItem("FJP L"+lb.to_s)
      if @sinCon.getItemText(lnodo) == "else"
        @labeler = @labeler + 2
        pCode(fnodo.next)
        @intCon.appendItem("UJP L"+(lb+1).to_s)
        @intCon.appendItem("LAB L"+lb.to_s)
        pCode(lnodo)
        @intCon.appendItem("LAB L"+(lb+1).to_s)
      else
        @labeler = @labeler + 1
        pCode(lnodo)
        @intCon.appendItem("LAB L"+lb.to_s)
      end
      pCode(nodo.next)
    elsif operator == "while"
      lb = @labeler
      @labeler = @labeler + 2
      @intCon.appendItem("LAB L"+lb.to_s)
      pCode(nodo.first)
      @intCon.appendItem("FJP L"+(lb+1).to_s)
      pCode(nodo.last)
      @intCon.appendItem("UJP L"+lb.to_s)
      @intCon.appendItem("LAB L"+(lb+1).to_s)
      pCode(nodo.next)
    elsif operator == "do"
      lb = @labeler
      @labeler = @labeler + 2
      @intCon.appendItem("LAB L"+lb.to_s)
      pCode(nodo.first)
      pCode(nodo.last)
      @intCon.appendItem("FJP L"+(lb+1).to_s)
      @intCon.appendItem("UJP L"+lb.to_s)
      @intCon.appendItem("LAB L"+(lb+1).to_s)
      pCode(nodo.next)
    elsif operator == "read"
      @intCon.appendItem("LDA "+@semCon.getItemText(nodo.first).split(" ")[0])
      @intCon.appendItem("RDI")
      pCode(nodo.next)
    elsif operator == "write"
      @intCon.appendItem("LOD "+@semCon.getItemText(nodo.first).split("[")[0])
      @intCon.appendItem("WRI")
      if nodo.last != nil
        @intCon.appendItem("LOD "+@semCon.getItemText(nodo.last).split(" ")[0])
        @intCon.appendItem("WRI")
      end
      pCode(nodo.next)
    elsif operator == "declaracion"
      pCode(nodo.next)
    elsif operator == "main" or operator == "Bloque" or operator == "then" or operator == "else" or operator == "until"
      pCode(nodo.first)
    else
      @intCon.appendItem("LOD " + operator)
    end
  end
end

#---------------------------------Función de generación de codigo objeto para TINY------------------------------------

def objCode(nodo)
  if nodo != nil
    operator = @sinCon.getItemText(nodo)
    if operator == "+"
      objCode(nodo.first)
      emitRM("ST",0,@tmpOff,6)
      @tmpOff -= 1
      objCode(nodo.last)
      @tmpOff += 1
      emitRM("LD",1,@tmpOff,6)
      emitRO("ADD",0,1,0)
    elsif operator == "-"
      objCode(nodo.first)
      emitRM("ST",0,@tmpOff,6)
      @tmpOff -= 1
      objCode(nodo.last)
      @tmpOff += 1
      emitRM("LD",1,@tmpOff,6)
      emitRO("SUB",0,1,0)
    elsif operator == "*"
      objCode(nodo.first)
      emitRM("ST",0,@tmpOff,6)
      @tmpOff -= 1
      objCode(nodo.last)
      @tmpOff += 1
      emitRM("LD",1,@tmpOff,6)
      emitRO("MUL",0,1,0)
    elsif operator == "/"
      objCode(nodo.first)
      emitRM("ST",0,@tmpOff,6)
      @tmpOff -= 1
      objCode(nodo.last)
      @tmpOff += 1
      emitRM("LD",1,@tmpOff,6)
      emitRO("DIV",0,1,0)
    elsif operator == "%"
      objCode(nodo.first)
      emitRM("ST",0,@tmpOff,6)
      @tmpOff -= 1
      objCode(nodo.last)
      @tmpOff += 1
      emitRM("LD",1,@tmpOff,6)
      emitRO("MOD",0,1,0)
    elsif operator == ":="
      objCode(nodo.last)
      loc = st_lookup(@sinCon.getItemText(nodo.first))
      emitRM("ST",0,loc,5)
      objCode(nodo.next)
    elsif isFloat(operator)
      emitRM("LDC",0,operator,0)
    elsif operator == "=="
      storage(nodo)
      emitRM("JEQ",0,2,7)
      saltos
    elsif operator == "!="
      storage(nodo)
      emitRM("JNE",0,2,7)
      saltos
    elsif operator == ">"
      storage(nodo)
      emitRM("JGT",0,2,7)
      saltos
    elsif operator == "<"
      storage(nodo)
      emitRM("JLT",0,2,7)
      saltos
    elsif operator == ">="
      storage(nodo)
      emitRM("JGE",0,2,7)
      saltos
    elsif operator == "<="
      storage(nodo)
      emitRM("JLE",0,2,7)
      saltos
    elsif operator == "if"
      fnodo = nodo.first
      objCode(fnodo)
      lb = emitSkip(1)
      lnodo = nodo.last
      if @sinCon.getItemText(lnodo) == "else"
        objCode(fnodo.next)
        lb2 = emitSkip(1)
        lb3 = emitSkip(0)
        @pointer = lb #emitBackup
        emitRM_Abs("JEQ",0,lb3)
        @pointer = @highPointer #restorePosition
        objCode(lnodo)
        lb4 = emitSkip(0)
        @pointer = lb2 #emitBackup
        emitRM_Abs("LDA",7,lb4)
        @pointer = @highPointer #restorePosition
      else
        objCode(lnodo)
        lb2 = emitSkip(1)
        lb3 = emitSkip(0)
        @pointer = lb
        emitRM_Abs("JEQ",0,lb3)
        @pointer = @highPointer #restorePosition
        lb4 = emitSkip(0)
        @pointer = lb2
        emitRM_Abs("LDA",7,lb4)
        @pointer = @highPointer #restorePosition
      end
      objCode(nodo.next)
    elsif operator == "while"
      lb = emitSkip(0)
      objCode(nodo.first)
      lb2 = emitSkip(1)
      objCode(nodo.last)
      lb3 = emitSkip(0)+1
      @pointer = lb2 #emitBackup
      emitRM_Abs("JEQ",0,lb3)
      @pointer = @highPointer #restorePosition
      emitRM_Abs("LDA",7,lb)
      objCode(nodo.next)
    elsif operator == "do"
      lb = emitSkip(0)
      objCode(nodo.first)
      objCode(nodo.last)
      emitRM_Abs("JEQ",0,lb)
      objCode(nodo.next)
    elsif operator == "read"
      emitRO("IN",0,0,0)
      loc = st_lookup(@sinCon.getItemText(nodo.first))
      emitRM("ST",0,loc,5)
      objCode(nodo.next)
    elsif operator == "write"
      txtr = @sinCon.getItemText(nodo.first)
      if nodo.first.next != nil then
        objCode(nodo.last)
        emitRO("OUT",0,0,txtr.strip)
      else
        emitRO("OUT",0,1,txtr.strip)
      end
      objCode(nodo.next)
    elsif operator == "declaracion"
      objCode(nodo.next)
    elsif operator == "main" or operator == "Bloque" or operator == "then" or operator == "else" or operator == "until"
      objCode(nodo.first)
    else
      loc = st_lookup(operator)
      emitRM("LD",0,loc,5)
    end
  end
end

def emitRM(op,r,d,s)
  @objetivo.puts(@pointer.to_s+": "+op.to_s+" "+r.to_s+","+d.to_s+"("+s.to_s+")")
  @pointer = @pointer + 1
  if @highPointer < @pointer then
    @highPointer = @pointer
  end
end

def emitRO(op,r,s,t)
  @objetivo.puts(@pointer.to_s+": "+op.to_s+" "+r.to_s+","+s.to_s+","+t.to_s)
  @pointer = @pointer + 1
  if @highPointer < @pointer then
    @highPointer = @pointer
  end
end

def emitRM_Abs(op,r,a)
  @objetivo.puts (@pointer.to_s+": "+op.to_s+" "+r.to_s+","+(a-(@pointer+1)).to_s+"(7)")
  @pointer = @pointer + 1
  if @highPointer < @pointer then
    @highPointer = @pointer
  end
end

def emitSkip(foot)
  pos = @pointer
  @pointer += foot
  if @highPointer < @pointer then
    @highPointer = @pointer
  end
  return pos
end

def st_lookup(variable)
  return @symbotable.keys.find_index(variable)
end

def saltos
  emitRM("LDC",0,0,0)
  emitRM("LDA",7,1,7)
  emitRM("LDC",0,1,0)
end

def storage(nodo)
  objCode(nodo.first)
  emitRM("ST",0,@tmpOff,6)
  @tmpOff -= 1
  objCode(nodo.last)
  @tmpOff += 1
  emitRM("LD",1,@tmpOff,6)
  emitRO("SUB",0,1,0)
end

#-------------------Funcion de expanción paralela de arboles semantico y sintactico-------------------

def expandir(data,data2)
  if data != nil
    @sinCon.expandTree(data)
    @semCon.expandTree(data2)
    expandir(data.next,data2.next)
    expandir(data.first,data2.first)
  end
end

# OPCODE
module OPCD
  OPHALT = 0
  OPIN = 1
  OPOUT = 2
  OPADD = 3
  OPSUB = 4
  OPMUL = 5
  OPDIV = 6
  OPMOD = 7
  OPRRLIM = 8
  OPLD = 9
  OPST = 10
  OPRMLIM = 11
  OPLDA = 12
  OPLDC = 13
  OPJLT = 14
  OPJLE = 15
  OPJGT = 16
  OPJGE = 17
  OPJEQ = 18
  OPJNE = 19
  OPRALIM = 20
end
#OPCLASS
module OPC
  OPCLRR = 0
  OPCLRM = 1
  OPCLRA = 2
end
#STEPRESULT
module STR
  SROKAY = 0
  SRHALT = 1
  SRIMEM_ERR = 2
  SRDMEM_ERR = 3
  SRZERODIVIDE = 4
  SRZEROMODULE = 5
end
#MACHINESETTINGS
module MCS
  IADDR_SIZE = 128
  DADDR_SIZE = 128
  NO_REGS = 8
  PC_REG = 7
  OPCODETAB = ["HALT","IN","OUT","ADD","SUB","MUL","DIV","MOD","????","LD","ST","????","LDA","LDC","JLT","JLE","JGT","JGE","JEQ","JNE","????"]
  STEPRESULTTAB = ["OK","Ejecucion Finalizada","ERROR: Falla de Memoria de Instruccion","ERROR: Falla de Memoria de Datos","ERROR: Division por Cero","ERROR: Modulo por Cero"]
end
#INATRUCTIONDATABASE
class Instruccion
  def initialize(op, it1, it2, it3)
    @iop = op
    @iarg1 = it1
    @iarg2 = it2
    @iarg3 = it3
  end

  def getIop
    return @iop
  end

  def getArg1
    return @iarg1
  end

  def getArg2
    return @iarg2
  end

  def getArg3
    return @iarg3
  end
end
#EXECUTIONVARIABLES
$iloc = 0
$dloc = 0
$traceflag = false
$icountflag = false
$in_Line = ""
$lineLen = 0
$inCol = 0
$num = 0
$word = ""
$strn = ""
$ch  = ""
$done = 0
########################################

def initialization(tmp)
  if tmp then
    $iMem = Array.new(MCS::IADDR_SIZE,Instruccion.new(OPCD::OPHALT,0,0,0))
  end
  $dMem = Array.new(MCS::DADDR_SIZE,0)
  $dMem[0] = MCS::DADDR_SIZE - 1
  $reg = [0,0,0,0,0,0,0,0]
end

def opClass( ct )
  if ct <= OPCD::OPRRLIM
    return OPC::OPCLRR
  elsif ct <= OPCD::OPRMLIM
    return OPC::OPCLRM
  else
    return OPC::OPCLRA
  end
end

def writeInstruction(loc)
  @resCon.appendText (loc.to_s)
  if loc >= 0 && loc < MCS::IADDR_SIZE then
    @resCon.appendText (MCS::OPCODETAB[$iMem[loc].getIop()]+" "+$iMem[loc].getArg1().to_s)
    case opClass($iMem[loc].getIop())
      when OPC::OPCLRR
        @resCon.appendText(" "+$iMem[loc].getArg2().to_s+" "+$iMem[loc].getArg3().to_s+"\n")
      when OPC::OPCLRM, OPC::OPCLRA
        @resCon.appendText(" "+$iMem[loc].getArg2().to_s+"("+$iMem[loc].getArg3().to_s+")\n")
    end
    @resCon.appendText ("\n")
  end
end

def getCh
  $inCol += 1
  if $inCol < $lineLen then
    $ch = $in_Line[$inCol]
  else
    $ch = " "
  end
end

def nonBlank
  while $inCol < $lineLen && $in_Line[$inCol] == " " do
    $inCol += 1
  end
  if $inCol < $lineLen then
    $ch = $in_Line[$inCol]
    return true
  else
    $ch = " "
    return false
  end
end

def getNum
  sign = 0
  term = 0
  $num = 0
  exp = 0.1
  temp = false
  flag = true
  begin
    sign = 1
    while nonBlank() && ($ch == "+" || $ch == "-") do
      temp = false
      if $ch == "-" then
        sign = -sign
      end
      getCh()
    end
    term = 0
    nonBlank()
    while $ch =~ /[[:digit:]]/ do
      temp = true
      if flag then
        term = term * 10 + $ch.to_i
      else
        term = term + exp*$ch.to_i
        exp /= 10
      end
      getCh()
      if $ch == "." then
        flag = false
        getCh()
      end
    end
    $num += (term * sign)
  end while nonBlank() && ($ch == "+" || $ch == "-")
  return temp
end

def getWord
  temp = false
  lengt = 0
  if nonBlank() then
    while $ch =~ /[[:alnum:]]/ do
      if lengt < 100 then
        $word << $ch
        lengt += 1
      end
      getCh()
    end
    temp = (lengt != 0)
  end
  return temp
end

def getString
  temp = false
  $strn = ""
  lengt = 0
  if nonBlank() then
    while $ch != "\"" do
      if lengt < 100 then
        $strn << $ch
        lengt += 1
      end
      getCh()
    end
    temp = (lengt != 0)
    if lengt == 0 && $ch == "\"" then
      temp = true
    end
  end
  return temp
end

def skipCh (chr)
  temp = false
  if nonBlank() && $ch == chr then
    getCh()
    temp = true
  end
  return temp
end

def atEOL
  return !nonBlank()
end

def error(msg,lineNo,instNo)
  @resCon.appendText("Linea "+lineNo.to_s+"\n")
  if instNo >= 0 then
    @resCon.appendText(" (Instruccion "+instNo.to_s+")\n")
  end
  @resCon.appendText("   "+msg.to_s+"\n")
  return false
end

def readInstructions
  op = 0
  arg1 = 0
  arg2 = 0
  arg3 = 0
  loc = 0
  lineNo = 0
  @objetiveTX = File.open("metadata/objetive.txt", 'r')
  while $in_Line = @objetiveTX.gets() do
    $inCol = 0
    lineNo += 1
    $lineLen = $in_Line.length-1
    $word = ""
    if $in_Line[$lineLen] =="\n" then
      $in_Line[$lineLen] = "\0"
    else
      $lineLen += 1
      $in_Line << "\0"
    end
    if nonBlank() && ($in_Line[$inCol] != "*") then
      if !getNum() then
        return error("Mala locación", lineNo,-1)
      end
      loc = $num
      if loc > MCS::IADDR_SIZE then
        return error("Locación demasiado Larga",lineNo,loc)
      end
      if !skipCh(":") then
        return error("Dos puntos perdidos", lineNo,loc)
      end
      if !getWord() then
        return error("Opcode perdido", lineNo,loc)
      end
      op = OPCD::OPHALT
      while op < OPCD::OPRALIM && MCS::OPCODETAB[op] != $word do
        op += 1
      end
      if MCS::OPCODETAB[op] != $word then
        return error("Opcode ilegal", lineNo,loc)
      end
      case (opClass(op))
        when OPC::OPCLRR
          skipCh(" ")
          if !getNum() || $num < 0 || $num >= MCS::NO_REGS then
            return error("Mal primer registro", lineNo,loc)
          end
          arg1 = $num
          if !skipCh(",") then
            return error("Coma perdida", lineNo, loc)
          end
          if !getNum() || $num < 0 || $num >= MCS::NO_REGS then
            return error("Mal segundo registro", lineNo, loc)
          end
          arg2 = $num
          if !skipCh(",") then
            return error("Coma perdida", lineNo,loc)
          end
          if $ch != "\"" then
            if !getNum() || $num < 0 || $num >= MCS::NO_REGS then
              return error("Mal tarcer registro", lineNo,loc)
            end
            arg3 = $num
          else
            skipCh("\"")
            if !getString() then
              return error("Mal tarcer registro", lineNo,loc)
            end
            arg3 = $strn
          end
        when OPC::OPCLRM, OPC::OPCLRA
          skipCh(" ")
          if !getNum() || $num < 0 || $num >= MCS::NO_REGS  then
            return error("Mal primer registro", lineNo,loc)
          end
          arg1 = $num
          if !skipCh(",") then
            return error("Coma perdida", lineNo,loc)
          end
          if !getNum() then
            return error("Mal desplazamiento", lineNo,loc)
          end
          arg2 = $num
          if !skipCh("(") && !skipCh(",")  then
            return error("Parentesis izquierdo perdido", lineNo,loc)
          end
          if !getNum() || $num < 0 || $num >= MCS::NO_REGS then
            return error("Mal segundo registro", lineNo,loc)
          end
          arg3 = $num
        else
      end
      $iMem[loc] = Instruccion.new(op,arg1,arg2,arg3)
    end
  end
  @objetiveTX.close
  return true
end

def stepTM
  r = 0
  s = 0
  t = 0
  m = 0
  ok = 0
  pc = $reg[MCS::PC_REG]
  if pc < 0 || pc > MCS::IADDR_SIZE then
    return STR::SRIMEM_ERR
  end
  $reg[MCS::PC_REG] = pc + 1
  currentinstruction = $iMem[pc]
  case (opClass(currentinstruction.getIop()))
    when OPC::OPCLRR
      r = currentinstruction.getArg1()
      s = currentinstruction.getArg2()
      t = currentinstruction.getArg3()
    when OPC::OPCLRM
      r = currentinstruction.getArg1()
      s = currentinstruction.getArg3()
      m = currentinstruction.getArg2() + $reg[s]
      if m < 0 || m > MCS::DADDR_SIZE then
        return STR::SRDMEM_ERR
      end
    when OPC::OPCLRA
      r = currentinstruction.getArg1()
      s = currentinstruction.getArg3()
      m = currentinstruction.getArg2() + $reg[s]
  end
  case currentinstruction.getIop()
    when OPCD::OPHALT
      return STR::SRHALT
    when OPCD::OPIN
      begin
        print("> ")
        @inputs = true
        while @inputs
          sleep 3
        end
        @inputs = false
        lst = @resCon.length-1
        fst = @resCon.startWord(lst)
        $in_Line = @resCon.extractText(fst,(lst+1)-fst)
        $lineLen = $in_Line.length
        $inCol = 0
        ok = getNum()
        if !ok then
          @resCon.appendText("Valor Ilegal\n")
        else
          $reg[r] = $num
        end
      end while !ok
    when OPCD::OPOUT
      if s == 0 then
        @resCon.appendText (t.to_s+$reg[r].to_s+"\n")
      else
        @resCon.appendText (t.to_s+"\n")
      end
    when OPCD::OPADD
      $reg[r] = $reg[s] + $reg[t]
    when OPCD::OPSUB
      $reg[r] = $reg[s] - $reg[t]
    when OPCD::OPMUL
      $reg[r] = $reg[s] * $reg[t]
    when OPCD::OPDIV
      if $reg[t] != 0 then
        $reg[r] = $reg[s] / $reg[t]
      else
        return STR::SRZERODIVIDE
      end
    when OPCD::OPMOD
      if $reg[t] != 0 then
        $reg[r] = $reg[s] % $reg[t]
      else
        return STR::SRZEROMODULE
      end
    when OPCD::OPLD
      $reg[r] = $dMem[m]
    when OPCD::OPST
      $dMem[m] = $reg[r]
    when OPCD::OPLDA
      $reg[r] = m
    when OPCD::OPLDC
      $reg[r] = currentinstruction.getArg2()
    when OPCD::OPJLT
      if $reg[r] < 0 then
        $reg[MCS::PC_REG] = m
      end
    when OPCD::OPJLE
      if $reg[r] <=  0 then
        $reg[MCS::PC_REG] = m
      end
    when OPCD::OPJGT
      if $reg[r] >  0 then
        $reg[MCS::PC_REG] = m
      end
    when OPCD::OPJGE
      if $reg[r] >=  0 then
        $reg[MCS::PC_REG] = m
      end
    when OPCD::OPJEQ
      if $reg[r] == 0 then
        $reg[MCS::PC_REG] = m
      end
    when OPCD::OPJNE
      if $reg[r] != 0 then
        $reg[MCS::PC_REG] = m
      end
  end
  return STR::SROKAY
end

def doCommand(val)
  cmd = val
  stepcnt = 0
  printcnt = 0
  stepResult = 0
  $loc = 0
  if cmd == "" then
    begin
      @resCon.appendText("Ingrese un Comando: \n")
      $in_Line = gets
      $lineLen = $in_Line.length
      $inCol = 0
    end while !getWord()
    cmd = $in_Line[0]
  end
  case (cmd)
    when "t"
      $traceflag = !$traceflag
      @resCon.appendText("Recorriendo ahora...\n")
      if $traceflag then
        @resCon.appendText("on.\n")
      else
        @resCon.appendText("off.\n")
      end
    when "h"
      @resCon.appendText("Comandos:")
      @resCon.appendText("   s(tep) <n>    Ejecutar n (por defecto 1) instrucciones de TM\n")
      @resCon.appendText("   g(o)          Ejecutar el programa\n")
      @resCon.appendText("   r(egs)        Mostrar el contenido de registros\n")
      @resCon.appendText("   i(Mem <b <n>> Imprimir n locaciones de iMem starting empezando por b\n")
      @resCon.appendText("   d(Mem <b <n>> Imprimir n locaciones de iMem starting empezando por b\n")
      @resCon.appendText("   t(race)       Mostrar rastro de instrucciones")
      @resCon.appendText("   p(rint)       Mostrar total de instrucciones ejecutadas('go' only)\n")
      @resCon.appendText("   c(lear)       Limpiar la memoria para nueva ejecución\n")
      @resCon.appendText("   h(elp)        Mostrar lista de comandos\n")
      @resCon.appendText("   q(uit)        Acabar con la simulación\n")
    when "p"
      $icountflag = !$icountflag
      @resCon.appendText("Imprimiendo la cuenta de instrucciones...\n")
      if $icountflag then
        @resCon.appendText("on.\n")
      else
        @resCon.appendText("off.\n")
      end
    when "s"
      if atEOL()
        stepcnt = 1
      elsif getNum()
        stepcnt = $num.abs
      else
        @resCon.appendText("Conteo de Pasos?\n")
      end
    when "g"
      stepcnt = 1
    when "r"
      for i in (0..(MCS::NO_REGS-1))
        @resCon.appendText(i.to_s+":"+$reg[i].to_s+"\n")
        if (i % 4) == 3 then
          @resCon.appendText("\n")
        end
      end
    when "c"
      $iloc = 0
      $dloc = 0
      stepcnt = 0
      initialization(false)
    when "q"
      return false
    else
      @resCon.appendText("Comando "+cmd+" no identificado.\n")
  end
  stepResult = STR::SROKAY
  if stepcnt > 0 then
    if cmd == "g" then
      stepcnt = 0
      while stepResult == STR::SROKAY do
        $iloc = $reg[MCS::PC_REG]
        if $traceflag then
          writeInstruction($iloc)
        end
        stepResult = stepTM()
        stepcnt += 1
      end
      if $icountflag then
        @resCon.appendText("Numero de instrucciones ejecutadas: "+stepcnt.to_s+"\n")
      end
    else
      while stepcnt > 0 && stepResult == STR::SROKAY do
        $iloc = $reg[MCS::PC_REG]
        if $traceflag then
          writeInstruction($iloc)
        end
        stepResult = stepTM()
        stepcnt -= 1
      end
    end
    @resCon.appendText(MCS::STEPRESULTTAB[stepResult]+"\n")
  end
  return true
end

def tinyMachineRun
  @resCon.appendText(" Simulación de TM\n");
  cmd = "g"
  begin
    done = !doCommand(cmd)
    cmd = ""
  end while !done
  @resCon.appendText("Simulación Terminada\n")
  return 0
end

#-----------------Función para iniciar el programa-------------

if __FILE__ == $0
  FXApp.new do |app|
    Compiler.new(app)
    app.create
    app.run
  end
end