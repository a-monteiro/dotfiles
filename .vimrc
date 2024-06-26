" Vundle
" set nocompatible              " be iMproved, required
filetype off                  " required
" set the runtime path to include Vundle and initialize
" set rtp+=~/.vim/bundle/Vundle.vim
 call vundle#begin()

 Plugin 'VundleVim/Vundle.vim'
 Plugin 'tpope/vim-sleuth'
 Plugin 'bling/vim-airline'
 Plugin 'powerline/fonts'  " NB: still need to run the ./install.sh script for the fonts to actually get installed
 Plugin 'scrooloose/nerdtree'
 Plugin 'kien/ctrlp.vim'
 Plugin 'scrooloose/syntastic.git'
 Plugin 'hashivim/vim-terraform'
 Plugin 'juliosueiras/vim-terraform-completion'
 Plugin 'EvitanRelta/vim-colorschemes'
 Plugin 'tpope/vim-surround'
 Plugin 'tpope/vim-repeat'
 Plugin 'easymotion/vim-easymotion'


let mapleader = " " " map leader to Space

" Use <Leader> instead of <Leader><Leader>
map <Leader> <Plug>(easymotion-prefix)
nmap s <Plug>(easymotion-overwin-f2)

if exists('g:vscode')
    " VSCode extension
    Plugin 'asvetliakov/vim-easymotion'
    xmap gc  <Plug>VSCodeCommentary
    nmap gc  <Plug>VSCodeCommentary
    omap gc  <Plug>VSCodeCommentary
    nmap gcc <Plug>VSCodeCommentaryLine
else
    " ordinary Neovim
endif


all vundle#end()            " required
filetype plugin indent on    " requirehow

" Airline
set laststatus=2
let g:airline_powerline_fonts=1

" Mappings
cmap w!! %!sudo tee > /dev/null %
" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[

" Various options
set ww=<,>,[,]               " Allow the right/left arrows to go to next and previous line
set number cursorline        " line numbering w/ cursor line highlighted
set showcmd                  " show incomplete cmds down the bottom
set lazyredraw               " do not redraw while running macros
set hlsearch incsearch       " highlighted, incremental search
set ignorecase smartcase     " smart casing
set dir=/tmp                 " where to put the swap files
set ttimeoutlen=50
set relativenumber
set clipboard=unnamed

set sh=bash                  " Ensure we use bash for script-out
set mouse=a
set shiftwidth=4
set encoding=utf-8
set tabstop=4 
set softtabstop=0 
set expandtab
set smarttab

if has('gui_running')
  " GUI config
  set background=dark
  colorscheme onedark
  set guifont=MesloLGS\ NF:h14
  " Automatically launch NERDtree
  au VimEnter *  NERDTree
else
  " CLI config
  set t_Co=256
  syntax on
  colorscheme onedark
endif

" Display hidden files in NERDTree by default
let NERDTreeShowHidden=1
let NERDTreeQuitOnOpen=1


" Syntactic: force python 3 mode
let g:syntastic_python_checkers = ['python']
let g:syntastic_python_python_exec = 'python3'

" Auto-format Terraform on save
let g:terraform_fmt_on_save=1
autocmd FileType terraform setlocal cc=7

map <leader>t :NERDTreeToggle<CR>

nmap j gj
nmap k gk

vnoremap < <gv
vnoremap > >gv
